/// ElNota — global application constants.
/// No logic here; only compile-time literals and named identifiers.
library;

class AppConstants {
  AppConstants._();

  // ── App identity ──────────────────────────────────────────────────────────
  static const String appName = 'ElNota';
  static const String appVersion = '1.0.5';

  // ── Database ───────────────────────────────────────────────────────────────
  static const int dbVersion = 3;
  static const String dbFileName = 'elnota.db';

  // ── GetStorage keys ────────────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLastSyncAt = 'last_sync_at';

  // ── Supported locales ──────────────────────────────────────────────────────
  static const String localeAr = 'ar';
  static const String localeEn = 'en';

  // ── Currency ───────────────────────────────────────────────────────────────
  /// Default currency code (ISO 4217). Change via settings in Phase 2.
  static const String defaultCurrencyCode = 'EGP';

  /// Minor-unit factor: 1 EGP = 100 piastres.
  static const int minorUnitFactor = 100;

  // ── Sync ────────────────────────────────────────────────────────────────────
  static const int syncMaxAttempts = 5;
  static const Duration syncBaseBackoff = Duration(seconds: 5);
}
