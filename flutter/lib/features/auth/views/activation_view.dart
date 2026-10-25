import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/account_access_service.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../admin/repositories/admin_repository.dart';
import '../repositories/activation_repository.dart';
import '../services/auth_service.dart';

class ActivationView extends StatefulWidget {
  const ActivationView({super.key});
  @override
  State<ActivationView> createState() => _ActivationViewState();
}

class _ActivationViewState extends State<ActivationView> {
  final phone = TextEditingController();
  final reference = TextEditingController();
  final repository = ActivationRepository();
  String? status, error;
  bool busy = false, admin = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final row = await repository.latest();
      final allowed = await AdminRepository().isAdmin();
      if (mounted) {
        setState(() {
          status = row?['status'] as String?;
          admin = allowed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'تعذر تحميل حالة الطلب. اتصل بالإنترنت وحدّث الحالة.',
        );
      }
    }
  }

  Future<void> send() async {
    if (busy) return;
    if (phone.text.trim().length < 7 || reference.text.trim().length < 3) {
      setState(() => error = 'أدخل رقم الهاتف ومرجع عملية الدفع');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.submit(phone: phone.text, reference: reference.text);
      if (mounted) setState(() => status = 'pending');
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'تعذر إرسال الطلب. تحقق من الاتصال ثم حدّث الحالة قبل إعادة الإرسال.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo.png', width: 64, height: 64),
                const SizedBox(height: 18),
                const Text(
                  'تفعيل حساب ElNota',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.to.currentSession.value?.email ?? '',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                const Text(
                  'استخدام التطبيق يتطلب موافقة الإدارة بعد التحقق من الدفع. بعد التفعيل تستطيع العمل محليًا دون إنترنت، بدون اشتراط اشتراك كلاود.',
                ),
                const SizedBox(height: 16),
                if (status == 'pending')
                  const DesignPill(
                    'طلبك قيد المراجعة — في انتظار موافقة الإدارة',
                  )
                else ...[
                  if (status == 'rejected')
                    const Text(
                      'لم تتم الموافقة على الطلب السابق. راجع بيانات الدفع قبل إرسال طلب جديد.',
                      style: TextStyle(color: Colors.red),
                    ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reference,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'مرجع عملية الدفع',
                      hintText:
                          'رقم التحويل أو التفاصيل المتفق عليها مع الإدارة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : send,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(busy ? 'جارٍ الإرسال…' : 'إرسال طلب التفعيل'),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),
                Obx(
                  () => OutlinedButton.icon(
                    onPressed: AccountAccessService.to.loading.value
                        ? null
                        : () async {
                            await AccountAccessService.to.refreshAccess();
                            if (mounted) await load();
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث حالة التفعيل'),
                  ),
                ),
                if (admin)
                  TextButton(
                    onPressed: () => Get.offAllNamed(AppRoutes.admin),
                    child: const Text('لوحة إدارة المنصة'),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await AuthService.to.signOut();
                          Get.offAllNamed(AppRoutes.login);
                        },
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
