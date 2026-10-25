import '../../../core/widgets/app_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_routes.dart';
import '../services/device_login_service.dart';
import '../services/auth_service.dart';

class DeviceLoginView extends StatefulWidget {
  const DeviceLoginView({super.key, this.dialog = false});
  final bool dialog;
  @override
  State<DeviceLoginView> createState() => _DeviceLoginViewState();
}

class _DeviceLoginViewState extends State<DeviceLoginView> {
  Map<String, dynamic>? challenge;
  String? error;
  bool loading = false;
  bool polling = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    create();
  }

  Future<void> create() async {
    timer?.cancel();
    setState(() {
      loading = true;
      error = null;
      challenge = null;
    });
    try {
      final value = await DeviceLoginApi.invoke({'action': 'create'});
      if (!mounted) return;
      setState(() => challenge = value);
      timer = Timer.periodic(const Duration(seconds: 2), (_) => poll());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'ربط الأجهزة غير متاح الآن. تأكد من اتصال الإنترنت وإعداد الخدمة.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> poll() async {
    final active = challenge;
    if (polling || active == null) return;
    if (DateTime.tryParse(
          active['expires_at'] as String,
        )?.isBefore(DateTime.now()) !=
        false) {
      timer?.cancel();
      setState(() {
        error = 'انتهت صلاحية الرمز. أنشئ رمزًا جديدًا.';
        challenge = null;
      });
      return;
    }
    polling = true;
    try {
      final result = await DeviceLoginApi.invoke({
        'action': 'poll',
        'id': active['id'],
        'secret': active['secret'],
      });
      if (!mounted || challenge != active) return;
      if (result['status'] == 'approved') {
        timer?.cancel();
        challenge = null;
        final response = await SupabaseService.to.client!.auth.verifyOTP(
          tokenHash: result['token_hash'] as String,
          type: OtpType.email,
        );
        if (response.session == null) throw StateError('Invalid session');
        if (!mounted) return;
        await AuthService.to.acceptServerSession();
        final destination = await AuthService.to.landingRoute();
        if (mounted) Get.offAllNamed(destination);
      } else if (result['status'] == 'expired') {
        timer?.cancel();
        setState(() {
          challenge = null;
          error = 'انتهت صلاحية الرمز';
        });
      }
    } catch (_) {
      if (mounted && challenge == null) {
        setState(() => error = 'تعذر إكمال الدخول. أنشئ رمزًا جديدًا.');
      }
    } finally {
      polling = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    challenge = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 480,
            child: DesignPanel(
              title: 'الدخول من تطبيق الموبايل',
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'امسح الرمز بكاميرا الموبايل وافتحه في تطبيق النوتة، ثم وافق على ربط المتصفح. لا تشارك الرمز مع الآخرين.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (loading)
                      const CircularProgressIndicator()
                    else if (challenge != null) ...[
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child: SvgPicture.string(
                          pw.Barcode.qrCode().toSvg(
                            challenge!['link'] as String,
                            width: 230,
                            height: 230,
                            drawText: false,
                          ),
                          width: 230,
                          height: 230,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'رمز التحقق: ${challenge!['code']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('وافق فقط إذا ظهر نفس الرمز على هاتفك.'),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: challenge!['id'] as String),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('نسخ كود الربط للإدخال يدويًا'),
                      ),
                    ],
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: loading ? null : create,
                      icon: const Icon(Icons.refresh),
                      label: const Text('رمز جديد'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.dialog) {
                          Navigator.of(context).pop();
                        } else {
                          Get.offAllNamed(AppRoutes.login);
                        }
                      },
                      child: const Text('الدخول بالبريد وكلمة المرور'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DeviceApprovalView extends StatefulWidget {
  const DeviceApprovalView({super.key, this.challengeId = ''});
  final String challengeId;
  @override
  State<DeviceApprovalView> createState() => _DeviceApprovalViewState();
}

class _DeviceApprovalViewState extends State<DeviceApprovalView> {
  late final input = TextEditingController(text: widget.challengeId);
  Map<String, dynamic>? details;
  String? error;
  bool busy = false;
  bool matches = false;
  String? inspectedId;
  @override
  void initState() {
    super.initState();
    if (widget.challengeId.isNotEmpty) inspect();
  }

  Future<void> inspect() async {
    setState(() {
      busy = true;
      error = null;
      details = null;
      matches = false;
    });
    try {
      final text = input.text.trim();
      final id = Uri.tryParse(text)?.queryParameters['challenge'] ?? text;
      final value = await DeviceLoginApi.invoke({
        'action': 'inspect',
        'id': id,
      });
      if (mounted) {
        setState(() {
          details = value;
          inspectedId = id;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'سجّل الدخول بحساب مفعّل على الهاتف، وتأكد أن الرمز لم تنتهِ صلاحيته.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approve() async {
    if (details == null || !matches || busy) return;
    setState(() => busy = true);
    try {
      await DeviceLoginApi.invoke({
        'action': 'approve',
        'id': inspectedId,
        'code': details!['code'],
      });
      if (mounted) {
        Get.back();
        AppToast.success('تمت الموافقة على دخول المتصفح', title: 'ربط الجهاز');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'تعذرت الموافقة. جرّب رمزًا جديدًا.';
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ربط متصفح جديد')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'لا توافق إلا على متصفح فتحته بنفسك. سيسمح الربط لهذا الجهاز بالدخول إلى حسابك.',
                style: TextStyle(color: designMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: input,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'كود الربط أو الرابط',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : inspect,
                child: const Text('فحص الرمز'),
              ),
              if (details != null) ...[
                const SizedBox(height: 20),
                Text('${details!['email']}', textAlign: TextAlign.center),
                Text(
                  '${details!['code']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('${details!['browser']}', textAlign: TextAlign.center),
                CheckboxListTile(
                  value: matches,
                  onChanged: busy ? null : (v) => setState(() => matches = v!),
                  title: const Text('الرمز مطابق للظاهر على متصفحي'),
                ),
                FilledButton(
                  onPressed: matches && !busy ? approve : null,
                  child: const Text('الموافقة على الدخول'),
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (busy) const Center(child: CircularProgressIndicator()),
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.login),
                child: const Text('تسجيل الدخول على الهاتف'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
