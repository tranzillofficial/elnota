import 'package:flutter/material.dart';

/// Design-token colour palette for ElNota.
/// Source: docs/DESIGN.md visual tokens.
abstract class AppColors {
  // ── Light palette ──────────────────────────────────────────────────────────
  static const Color canvasLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF6F8FB);
  static const Color textPrimaryLight = Color(0xFF101326);
  static const Color textSecondaryLight = Color(0xFF59698D);
  static const Color borderLight = Color(0xFFE4E9F2);

  // ── Dark palette ───────────────────────────────────────────────────────────
  static const Color canvasDark = Color(0xFF121619);
  static const Color surfaceDark = Color(0xFF1C2226);
  static const Color surfaceVariantDark = Color(0xFF242B30);
  static const Color textPrimaryDark = Color(0xFFF3F5F4);
  static const Color textSecondaryDark = Color(0xFF8FA4AE);
  static const Color borderDark = Color(0xFF30383C);

  // ── Semantic / brand ───────────────────────────────────────────────────────
  /// Primary accent: restrained green — trust and money.
  static const Color accent = Color(0xFF00845B);
  static const Color accentDark = Color(0xFF2D8570);

  static const Color danger = Color(0xFFEF1111);
  static const Color warning = Color(0xFFB7791F);
  static const Color success = Color(0xFF2E7D52);
  static const Color info = Color(0xFF1B6B9E);

  // ── Sync status indicators ─────────────────────────────────────────────────
  static const Color syncPending = Color(0xFFB7791F); // warning amber
  static const Color syncOk = Color(0xFF2E7D52); // success green
  static const Color syncFailed = Color(0xFFEF1111); // danger red
  static const Color savedLocally = Color(0xFF1B6B9E); // info blue
}
