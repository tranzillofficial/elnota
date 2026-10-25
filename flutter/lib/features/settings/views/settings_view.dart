import 'package:file_picker/file_picker.dart';
import '../../../core/services/backup_import_plan.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/business_profile.dart';
import 'package:get_storage/get_storage.dart';
import '../../admin/repositories/admin_repository.dart';
import '../../auth/views/device_login_view.dart';
import '../../auth/views/device_scanner_view.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/account_access_service.dart';
import '../../../core/utils/app_runtime.dart';
import '../../../core/services/daily_backup_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/services/sync_service.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/utils/app_constants.dart';
import '../../auth/services/auth_service.dart';
import '../../invoices/models/invoice_model.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsController ctrl;
  late final adminAccess = AdminRepository().isAdmin().catchError((_) => false);
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<SettingsController>()) Get.put(SettingsController());
    ctrl = Get.find<SettingsController>();
  }

  bool importing = false;
  Future<void> importBackup() async {
    if (importing) return;
    importing = true;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return;
      final content = utf8.decode(await files.single.readAsBytes());
      final uid = SupabaseService.to.client?.auth.currentUser?.id;
      if (uid == null) throw StateError('سجّل الدخول أولًا');
      final plan = BackupImportPlan.parse(content, accountId: uid);
      await plan.prepareLegacyImages();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('مراجعة الاستيراد'),
          content: SingleChildScrollView(
            child: Text(
              'عملاء: ${plan.count('customers')}\nفواتير: ${plan.count('invoices')}\nدفعات: ${plan.count('payments')}\nمنتجات: ${plan.count('catalog_products')}\nصافي الأرصدة: ${(plan.balanceMinor / 100).toStringAsFixed(2)} ج.م\n\n${plan.warnings.join('\n')}\n\nأؤكد أن هذا الملف يخص الحساب المفتوح.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استيراد إلى دفتر فارغ'),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          uid != SupabaseService.to.client?.auth.currentUser?.id) {
        return;
      }
      final imported = await DatabaseService.to.dao.importBackup(plan);
      if (imported && plan.profile.isNotEmpty) {
        await GetStorage().write(BusinessProfile.key, {
          ...BusinessProfile.values,
          ...plan.profile,
        });
        ctrl.businessName.text =
            plan.profile['name'] as String? ?? ctrl.businessName.text;
        ctrl.phone.text = plan.profile['phone'] as String? ?? ctrl.phone.text;
        ctrl.address.text =
            plan.profile['address'] as String? ?? ctrl.address.text;
      }
      AppToast.info(
        imported
            ? 'تم الاستيراد وحفظ الملف الأصلي محليًا'
            : 'هذه النسخة مستوردة بالفعل؛ لم تتكرر البيانات',
      );
    } catch (e) {
      AppToast.error(
        e is FormatException
            ? e.message.toString()
            : e is StateError
            ? e.message
            : 'تعذر الاستيراد. لم يتم تغيير الدفتر.',
      );
    } finally {
      importing = false;
    }
  }

  Future<void> save() async {
    try {
      if (await ctrl.save() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التغييرات على هذا الجهاز')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر حفظ الإعدادات')));
      }
    }
  }

  Future<void> preview(bool print) async {
    final bytes = await PdfService.generateInvoicePdf(
      invoice: InvoiceModel(
        id: 'PREVIEW',
        customerId: '',
        status: 'preview',
        totalMinor: 10000,
        discountMinor: 0,
        isManualAmount: true,
        invoiceDate: DateTime.now(),
        notes: 'معاينة تجريبية — لا تُسجّل في الحسابات',
      ),
      customerName: 'اختبار طباعة',
    );
    if (print) {
      await PdfService.printDocument(bytes, name: 'ElNota Print Test');
    } else if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 650,
            height: 750,
            child: PdfPreview(
              build: (_) async => bytes,
              canChangePageFormat: false,
              canChangeOrientation: false,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final sync = Get.isRegistered<SyncService>() ? SyncService.to : null;
    final connectivity = Get.isRegistered<ConnectivityService>()
        ? ConnectivityService.to
        : null;
    final business = DesignPanel(
      title: 'بيانات النشاط',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => Wrap(
                spacing: 18,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ctrl.logo.value == null
                        ? Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                          )
                        : Image.memory(
                            base64Decode(ctrl.logo.value!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                  ),
                  const SizedBox(width: 18),
                  OutlinedButton.icon(
                    onPressed: ctrl.pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('تغيير الشعار'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FormColumns(
              children: [
                LabeledField(
                  'اسم النشاط',
                  child: TextField(controller: ctrl.businessName),
                ),
                LabeledField(
                  'رقم الهاتف',
                  child: TextField(
                    controller: ctrl.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LabeledField('العنوان', child: TextField(controller: ctrl.address)),
            const SizedBox(height: 14),
            const Text(
              'تظهر هذه البيانات على الفواتير المطبوعة من هذا الجهاز.',
              style: TextStyle(color: designMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    final printing = DesignPanel(
      title: 'الطباعة والفواتير',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Obx(
              () => LabeledField(
                'الطابعة الافتراضية',
                child: DropdownButtonFormField<String>(
                  key: ValueKey(ctrl.selectedPrinter.value),
                  initialValue:
                      ctrl.printers.any(
                        (p) => p.url == ctrl.selectedPrinter.value,
                      )
                      ? ctrl.selectedPrinter.value
                      : null,
                  isExpanded: true,
                  hint: const Text('طابعة النظام'),
                  items: ctrl.printers
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.url, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) => ctrl.selectedPrinter.value = v,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Obx(
              () => _SettingRow(
                'مقاس الورق',
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '80', label: Text('80 مم')),
                    ButtonSegment(value: '58', label: Text('58 مم')),
                    ButtonSegment(value: 'A4', label: Text('A4')),
                  ],
                  selected: {ctrl.paper.value},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => ctrl.paper.value = v.first,
                ),
              ),
            ),
            Obx(
              () => Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('عرض الشعار على الفاتورة'),
                  value: ctrl.showLogo.value,
                  onChanged: (v) => ctrl.showLogo.value = v,
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DesignAction(
                  'اختبار الطباعة',
                  Icons.print_outlined,
                  () => preview(true),
                ),
                DesignAction(
                  'معاينة الفاتورة',
                  Icons.visibility_outlined,
                  () => preview(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    Widget syncContent() {
      final summary = sync?.summary.value;
      final cloud =
          Get.isRegistered<AccountAccessService>() &&
          AccountAccessService.to.cloudEnabled;
      final backup = Get.isRegistered<DailyBackupService>()
          ? Get.find<DailyBackupService>()
          : null;
      final online = connectivity?.isOnline.value ?? false;
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                DesignPill(
                  online ? 'متصل' : 'يعمل محليًا',
                  color: online ? designGreen : Colors.orange,
                ),
                Text('العمليات المعلقة: ${summary?.pendingCount ?? 0}'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'آخر مزامنة ناجحة: ${summary?.lastSuccessAt == null ? 'لم تتم بعد' : designDate(summary!.lastSuccessAt!)}',
              style: const TextStyle(color: designMuted),
            ),
            const SizedBox(height: 16),
            _SettingRow(
              'حالة الحساب',
              Text(
                cloud ? 'كلاود نشط' : 'محلي — بيانات مستقلة على كل جهاز',
                style: const TextStyle(color: designMuted),
              ),
            ),
            _SettingRow(
              'النسخ الاحتياطي اليومي',
              Text(
                !cloud
                    ? 'لعملاء الكلاود فقط'
                    : DailyBackupService.backendEnabled
                    ? 'منتصف الليل بتوقيت الجهاز؛ إعادة المحاولة عند الاتصال'
                    : 'بانتظار تفعيل خدمة النسخ الجديدة',
                style: const TextStyle(color: designMuted),
              ),
            ),
            if (backup?.lastUploaded.value != null)
              Text(
                'آخر نسخة: ${backup!.lastUploaded.value}',
                style: const TextStyle(color: designMuted, fontSize: 12),
              ),
            if (backup?.error.value != null)
              Text(
                backup!.error.value!,
                style: const TextStyle(color: designMuted, fontSize: 12),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: !cloud || sync == null || summary?.isSyncing == true
                  ? null
                  : () async {
                      final ok = await sync.syncNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok && sync.summary.value.lastSuccessAt != null
                                  ? 'اكتملت محاولة المزامنة'
                                  : 'البيانات محفوظة محليًا؛ لم يتم تأكيد المزامنة',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.sync),
              label: Text(
                summary?.isSyncing == true ? 'جارٍ المزامنة…' : 'مزامنة الآن',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DesignAction(
                  'تصدير نسخة محلية',
                  Icons.download_outlined,
                  () async {
                    if (!cloud) {
                      AppToast.info('النسخ الاحتياطي متاح لاشتراك الكلاود فقط');
                      return;
                    }
                    try {
                      await BackupService().exportAndShareBackup();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر تصدير النسخة')),
                        );
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: importBackup,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('استيراد نسخة قديمة أو جديدة'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final backups = DesignPanel(
      title: 'النسخ الاحتياطي والمزامنة',
      child:
          sync != null ||
              connectivity != null ||
              Get.isRegistered<AccountAccessService>()
          ? Obx(syncContent)
          : syncContent(),
    );
    final preferences = DesignPanel(
      title: 'تفضيلات التطبيق',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (Get.isRegistered<ThemeService>())
              Obx(
                () => _SettingRow(
                  'المظهر',
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'light', label: Text('فاتح')),
                      ButtonSegment(value: 'dark', label: Text('داكن')),
                      ButtonSegment(value: 'system', label: Text('النظام')),
                    ],
                    selected: {ThemeService.to.mode.name},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) {
                      if (v.first == 'light') ctrl.onThemeLightTapped();
                      if (v.first == 'dark') ctrl.onThemeDarkTapped();
                      if (v.first == 'system') ctrl.onThemeSystemTapped();
                    },
                  ),
                ),
              ),
            const _SettingRow(
              'قفل التطبيق',
              Text('غير مفعّل', style: TextStyle(color: designMuted)),
            ),
            const _SettingRow(
              'تنبيهات الأقساط',
              Text('غير مفعّلة', style: TextStyle(color: designMuted)),
            ),
            FutureBuilder<bool>(
              future: adminAccess,
              builder: (context, snapshot) => snapshot.data == true
                  ? TextButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.admin),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('لوحة الإدارة'),
                    )
                  : const SizedBox.shrink(),
            ),
            _SettingRow(
              'ربط متصفح',
              TextButton.icon(
                onPressed: () => Get.to(
                  () =>
                      !kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.android ||
                              defaultTargetPlatform == TargetPlatform.iOS)
                      ? const DeviceScannerView()
                      : const DeviceApprovalView(),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('مسح QR لربط جهاز'),
              ),
            ),
            _SettingRow(
              'اللغة',
              TextButton(
                onPressed: ctrl.onLanguageToggled,
                child: Text(ctrl.localeLabel),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  '${AppConstants.appName} · الإصدار ${ctrl.appVersion}',
                  style: const TextStyle(color: designMuted),
                ),
                TextButton.icon(
                  onPressed: AppRuntime.demo
                      ? null
                      : () async {
                          if (auth?.isAuthenticated == true) {
                            await auth!.signOut();
                            Get.offAllNamed(AppRoutes.login);
                          } else {
                            Get.toNamed(AppRoutes.login);
                          }
                        },
                  icon: const Icon(Icons.logout),
                  label: Text(
                    AppRuntime.demo
                        ? 'الديمو لا يحتاج تسجيل دخول'
                        : auth?.isAuthenticated == true
                        ? 'تسجيل الخروج'
                        : 'الحساب وتسجيل الدخول',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
          ),
          children: [
            DesignHeader(
              title: 'الإعدادات',
              subtitle: 'إدارة بيانات نشاطك وتفضيلات التطبيق',
              actions: [
                Obx(
                  () => FilledButton.icon(
                    onPressed: ctrl.saving.value ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      ctrl.saving.value ? 'جارٍ الحفظ…' : 'حفظ التغييرات',
                    ),
                  ),
                ),
              ],
            ),
            DesignPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    Text(
                      auth?.currentSession.value?.email ?? 'الحساب المحلي',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const DesignPill('تفضيلات محفوظة محليًا'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 1100
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              business,
                              const SizedBox(height: 16),
                              printing,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              backups,
                              const SizedBox(height: 16),
                              preferences,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        business,
                        const SizedBox(height: 16),
                        printing,
                        const SizedBox(height: 16),
                        backups,
                        const SizedBox(height: 16),
                        preferences,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(this.label, this.control);
  final String label;
  final Widget control;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: LayoutBuilder(
      builder: (context, box) => box.maxWidth < 500
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                control,
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(child: control),
              ],
            ),
    ),
  );
}
