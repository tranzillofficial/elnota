import 'package:flutter/material.dart';

/// Typography tokens for ElNota.
/// Primary typeface: Cairo (Arabic-first, clear numerals).
/// Fallback: system default if Cairo is unavailable.
abstract class AppTextStyles {
  static const String _fontFamily = 'Cairo';

  // ── Scale (sp) ──────────────────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Tabular/monospaced numerals for amounts and balances.
  static const TextStyle amount = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
  );
}

/// Typography for the Material ThemeData.
TextTheme buildTextTheme(Color primaryText, Color secondaryText) {
  return TextTheme(
    displayLarge: AppTextStyles.display.copyWith(color: primaryText),
    displayMedium: AppTextStyles.display.copyWith(fontSize: 22, color: primaryText),
    displaySmall: AppTextStyles.heading.copyWith(color: primaryText),
    headlineLarge: AppTextStyles.heading.copyWith(color: primaryText),
    headlineMedium: AppTextStyles.subheading.copyWith(color: primaryText),
    headlineSmall: AppTextStyles.subheading.copyWith(fontSize: 15, color: primaryText),
    titleLarge: AppTextStyles.subheading.copyWith(color: primaryText),
    titleMedium: AppTextStyles.bodyMedium.copyWith(color: primaryText),
    titleSmall: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: primaryText),
    bodyLarge: AppTextStyles.body.copyWith(fontSize: 16, color: primaryText),
    bodyMedium: AppTextStyles.body.copyWith(color: primaryText),
    bodySmall: AppTextStyles.caption.copyWith(color: secondaryText),
    labelLarge: AppTextStyles.label.copyWith(fontSize: 14, color: primaryText),
    labelMedium: AppTextStyles.label.copyWith(color: secondaryText),
    labelSmall: AppTextStyles.label.copyWith(fontSize: 10, color: secondaryText),
  );
}
