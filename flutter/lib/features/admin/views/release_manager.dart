import '../../../core/widgets/accounting_form_frame.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_runtime.dart';
import '../../../core/widgets/design_widgets.dart';
import '../repositories/admin_repository.dart';

class ReleaseManager extends StatefulWidget {
  const ReleaseManager({super.key});
  @override
  State<ReleaseManager> createState() => _ReleaseManagerState();
}

class _ReleaseManagerState extends State<ReleaseManager> {
  final version = TextEditingController();
  final url = TextEditingController();
  final notes = TextEditingController();
  String platform = 'android';
  bool store = false;
  bool externalLink = false;
  bool busy = false;
  String? message;
  PlatformFile? file;
  String? supportUrl;

  Future<void> uploadSupport() async {
    if (busy || AppRuntime.demo) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (!await AdminRepository().isAdmin()) {
        throw StateError('Admin required');
      }
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (files.isEmpty) return;
      final selected = files.single;
      final size = await selected.length();
      if (selected.extension?.toLowerCase() != 'zip' ||
          size == null ||
          size == 0) {
        throw StateError('Invalid file');
      }
      final client = SupabaseService.to.client!;
      final path =
          'windows/${DateTime.now().microsecondsSinceEpoch}/elnota-support.zip';
      await client.storage
          .from('elnota-app-releases')
          .uploadBinary(path, await selected.readAsBytes());
      if (mounted) {
        setState(
          () => supportUrl = client.storage
              .from('elnota-app-releases')
              .getPublicUrl(path),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'تعذر الرفع إلى مزود التخزين. للملفات الكبيرة استخدم رابط إصدار منشور على GitHub.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    version.dispose();
    url.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> publish() async {
    if (busy) return;
    if (!RegExp(
      r'^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$',
    ).hasMatch(version.text.trim())) {
      setState(() => message = 'اكتب رقم إصدار مثل 1.0.1');
      return;
    }
    final uri = Uri.tryParse(url.text.trim());
    if (store &&
        (uri == null ||
            uri.scheme != 'https' ||
            (platform == 'android'
                ? uri.host != 'play.google.com' ||
                      uri.path != '/store/apps/details' ||
                      !uri.queryParameters.containsKey('id')
                : uri.host != 'apps.apple.com'))) {
      setState(() => message = 'أدخل رابط التطبيق الرسمي في المتجر');
      return;
    }
    if (!store &&
        !externalLink &&
        (file == null || (await file!.length() ?? 0) == 0)) {
      setState(() => message = 'اختر ملف الإصدار');
      return;
    }
    if (externalLink &&
        !store &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'github.com' ||
            !uri.path.startsWith(
              '/tranzillofficial/elnotaapp/releases/download/',
            ))) {
      setState(
        () => message =
            'استخدم رابط تحميل من إصدارات مستودع elnotaapp على GitHub',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (AppRuntime.demo || !await AdminRepository().isAdmin()) {
        throw StateError('صلاحية الإدارة مطلوبة');
      }
      final client = SupabaseService.to.client!;
      var download = url.text.trim();
      if (!store && !externalLink) {
        final extension = file!.extension?.toLowerCase();
        if (!(platform == 'android' ? ['apk'] : ['exe', 'msi']).contains(
          extension,
        )) {
          throw StateError('نوع الملف غير مناسب للمنصة');
        }
        final path =
            '$platform/${DateTime.now().microsecondsSinceEpoch}/elnota-${version.text.trim().replaceAll('+', '-')}.$extension';
        await client.storage
            .from('elnota-app-releases')
            .uploadBinary(path, await file!.readAsBytes());
        download = client.storage
            .from('elnota-app-releases')
            .getPublicUrl(path);
      }
      await client.rpc(
        'elnota_publish_release',
        params: {
          'p_platform': platform,
          'p_version': version.text.trim(),
          'p_distribution': store ? 'store' : 'file',
          'p_url': download,
          'p_notes': notes.text.trim(),
        },
      );
      if (mounted) {
        setState(
          () => message = 'تم نشر الإصدار. يظهر رابط التحميل خلال دقيقة.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'تعذر النشر. راجع صلاحياتك واتصالك. لو تجاوز الملف حدود مزود التخزين، اختار رابط إصدار GitHub.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: DesignPanel(
        title: 'نشر إصدار جديد',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormColumns(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: platform,
                    decoration: const InputDecoration(
                      labelText: 'المنصة',
                      prefixIcon: Icon(Icons.devices_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'android',
                        child: Text('Android'),
                      ),
                      DropdownMenuItem(
                        value: 'windows',
                        child: Text('Windows 64-bit'),
                      ),
                      DropdownMenuItem(value: 'ios', child: Text('iOS')),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            platform = value!;
                            file = null;
                            store = platform == 'ios';
                            externalLink = false;
                          }),
                  ),
                  TextField(
                    controller: version,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'رقم الإصدار',
                      hintText: '1.0.1',
                      prefixIcon: Icon(Icons.new_releases_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'مصدر التحميل',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (platform != 'ios')
                    ChoiceChip(
                      label: const Text('رفع ملف'),
                      avatar: const Icon(Icons.upload_file, size: 18),
                      selected: !store && !externalLink,
                      onSelected: busy
                          ? null
                          : (_) => setState(() {
                              store = false;
                              externalLink = false;
                            }),
                    ),
                  if (platform != 'ios')
                    ChoiceChip(
                      label: const Text('رابط إصدار GitHub'),
                      selected: externalLink && !store,
                      onSelected: busy
                          ? null
                          : (_) => setState(() {
                              externalLink = true;
                              store = false;
                            }),
                    ),
                  if (platform != 'windows')
                    ChoiceChip(
                      label: const Text('رابط المتجر'),
                      selected: store,
                      onSelected: busy
                          ? null
                          : (_) => setState(() {
                              store = true;
                              externalLink = false;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (store || externalLink)
                TextField(
                  controller: url,
                  enabled: !busy,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: store
                        ? 'رابط التطبيق في المتجر'
                        : 'رابط الملف المنشور على GitHub',
                    prefixIcon: const Icon(Icons.link),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00845B).withValues(alpha: 0.04),
                    border: Border.all(color: designBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 30,
                        color: Color(0xFF00845B),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file?.name ??
                            (platform == 'android'
                                ? 'اختر ملف APK'
                                : 'اختر مثبّت EXE أو MSI'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final files = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: platform == 'android'
                                      ? ['apk']
                                      : ['exe', 'msi'],
                                );
                                if (mounted && files.isNotEmpty) {
                                  setState(() => file = files.single);
                                }
                              },
                        child: const Text('اختيار الملف'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'التطبيق لا يفرض حدًا لحجم الإصدار. لو تجاوز الملف حدود مزود التخزين، انشره على GitHub واستخدم رابط الإصدار.',
                style: TextStyle(color: designMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                enabled: !busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ما الجديد في الإصدار؟',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: busy ? null : publish,
                  icon: const Icon(Icons.publish, size: 18),
                  label: Text(busy ? 'جارٍ النشر…' : 'نشر الإصدار'),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(message!),
                ),
              const Divider(height: 32),
              const Text(
                'الملفات المساعدة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : uploadSupport,
                  icon: const Icon(Icons.folder_zip_outlined, size: 18),
                  label: const Text('رفع ملف ZIP'),
                ),
              ),
              if (supportUrl != null)
                SelectableText('رابط الملفات: $supportUrl'),
            ],
          ),
        ),
      ),
    ),
  );
}
