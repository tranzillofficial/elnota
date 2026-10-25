import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/utils/app_constants.dart';

/// Persists and exposes the user's selected [Locale].
/// Consumed by [GetMaterialApp] via [locale].
class LocaleService extends GetxService {
  static LocaleService get to => Get.find<LocaleService>();

  final _box = GetStorage();

  final _locale = const Locale('ar').obs;

  Locale get locale => _locale.value;

  /// True when the current locale is Arabic.
  bool get isArabic => _locale.value.languageCode == AppConstants.localeAr;

  /// RTL direction follows the Arabic locale.
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLocale();
  }

  void _loadSavedLocale() {
    final saved = _box.read<String>(AppConstants.keyLocale);
    if (saved != null) {
      _locale.value = Locale(saved);
      Get.updateLocale(Locale(saved));
    }
  }

  void setArabic() => _setLocale(AppConstants.localeAr);
  void setEnglish() => _setLocale(AppConstants.localeEn);

  void toggleLocale() {
    if (isArabic) {
      setEnglish();
    } else {
      setArabic();
    }
  }

  void _setLocale(String code) {
    _locale.value = Locale(code);
    _box.write(AppConstants.keyLocale, code);
    Get.updateLocale(Locale(code));
  }
}
