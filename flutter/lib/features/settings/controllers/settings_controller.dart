import '../../../core/services/business_profile.dart';
import '../../../core/widgets/app_toast.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../auth/services/auth_service.dart';

class SettingsController extends GetxController {
  static SettingsController get to => Get.find<SettingsController>();
  final store = GetStorage();
  final businessName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final paper = 'A4'.obs;
  final showLogo = true.obs;
  final saving = false.obs;
  final selectedPrinter = Rxn<String>();
  final printers = <Printer>[].obs;
  final logo = Rxn<String>();
  final printerError = Rxn<String>();
  ThemeService get _theme => ThemeService.to;
  LocaleService get _locale => LocaleService.to;
  bool get isDark => _theme.isDark;
  bool get isArabic => _locale.isArabic;
  String get appVersion => AppConstants.appVersion;
  String get themeModeLabel => _theme.mode.name;
  String get localeLabel => isArabic ? 'العربية' : 'English';
  @override
  void onInit() {
    super.onInit();
    final saved = store.read<Map>(BusinessProfile.key) ?? {};
    businessName.text =
        saved['name'] as String? ??
        (Get.isRegistered<AuthService>()
            ? AuthService.to.currentSession.value?.workspaceName
            : null) ??
        '';
    phone.text = saved['phone'] as String? ?? '';
    address.text = saved['address'] as String? ?? '';
    paper.value = saved['paper'] as String? ?? 'A4';
    showLogo.value = saved['showLogo'] as bool? ?? true;
    selectedPrinter.value = saved['printer'] as String?;
    logo.value = saved['logo'] as String?;
    loadPrinters();
  }

  Future<void> loadPrinters() async {
    try {
      printers.assignAll(await Printing.listPrinters());
    } catch (_) {
      printerError.value =
          'اختيار الطابعة متاح من نافذة الطباعة على هذا الجهاز';
    }
  }

  Future<void> pickLogo() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final length = await files.single.length();
    if (length != null && length > 2 * 1024 * 1024) {
      AppToast.error('اختر صورة أصغر من 2 ميجابايت', title: 'الشعار');
      return;
    }
    final bytes = await files.single.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      AppToast.error('اختر صورة أصغر من 2 ميجابايت', title: 'الشعار');
      return;
    }
    logo.value = base64Encode(bytes);
  }

  Future<bool> save() async {
    if (saving.value) return false;
    if (businessName.text.trim().isEmpty) {
      AppToast.error('اكتب اسم النشاط', title: 'بيانات النشاط');
      return false;
    }
    saving.value = true;
    try {
      await store.write(BusinessProfile.key, {
        'name': businessName.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'paper': paper.value,
        'showLogo': showLogo.value,
        'printer': selectedPrinter.value,
        'logo': logo.value,
      });
      return true;
    } finally {
      saving.value = false;
    }
  }

  void onThemeLightTapped() => _theme.setLight();
  void onThemeDarkTapped() => _theme.setDark();
  void onThemeSystemTapped() => _theme.setSystem();
  void onToggleTheme() => _theme.toggle();
  void onLanguageToggled() => _locale.toggleLocale();
  void onArabicSelected() => _locale.setArabic();
  void onEnglishSelected() => _locale.setEnglish();
  @override
  void onClose() {
    businessName.dispose();
    phone.dispose();
    address.dispose();
    super.onClose();
  }
}
