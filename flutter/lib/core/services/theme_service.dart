import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../app/theme/app_theme.dart';
import '../utils/app_constants.dart';

/// Persists and exposes the user's selected [ThemeMode].
/// Consumed by [GetMaterialApp] via [themeMode] and [theme]/[darkTheme].
class ThemeService extends GetxService {
  static ThemeService get to => Get.find<ThemeService>();

  final _box = GetStorage();

  final _mode = ThemeMode.system.obs;

  ThemeMode get mode => _mode.value;
  ThemeData get lightTheme => AppTheme.light;
  ThemeData get darkTheme => AppTheme.dark;

  @override
  void onInit() {
    super.onInit();
    _loadSavedMode();
  }

  void _loadSavedMode() {
    final saved = _box.read<String>(AppConstants.keyThemeMode);
    _mode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setLight() => _setMode(ThemeMode.light, 'light');
  void setDark() => _setMode(ThemeMode.dark, 'dark');
  void setSystem() => _setMode(ThemeMode.system, 'system');

  void toggle() {
    if (_mode.value == ThemeMode.light) {
      setDark();
    } else {
      setLight();
    }
  }

  bool get isDark {
    if (_mode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return _mode.value == ThemeMode.dark;
  }

  void _setMode(ThemeMode mode, String key) {
    _mode.value = mode;
    _box.write(AppConstants.keyThemeMode, key);
    Get.changeThemeMode(mode);
  }
}
