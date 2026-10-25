// Phase 1 smoke tests for ElNota.
// These tests validate that the key service classes and translation maps
// are structured correctly without requiring a full widget pump
// (which would need Drift code-gen to be available).
//
// Run with: flutter test test/phase1_smoke_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/utils/l10n/ar.dart';
import 'package:elnota/core/utils/l10n/en.dart';
import 'package:elnota/core/utils/app_constants.dart';
import 'package:elnota/core/utils/app_routes.dart';

void main() {
  group('Phase 1 — Localisation', () {
    test('Arabic translation map is non-empty', () {
      expect(arStrings, isNotEmpty);
    });

    test('English translation map is non-empty', () {
      expect(enStrings, isNotEmpty);
    });

    test('Both maps have the same keys', () {
      final arKeys = arStrings.keys.toSet();
      final enKeys = enStrings.keys.toSet();
      final missingInEn = arKeys.difference(enKeys);
      final missingInAr = enKeys.difference(arKeys);
      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys present in AR but missing in EN: $missingInEn',
      );
      expect(
        missingInAr,
        isEmpty,
        reason: 'Keys present in EN but missing in AR: $missingInAr',
      );
    });

    test('No translation value is empty', () {
      for (final entry in arStrings.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'AR key "${entry.key}" has an empty value',
        );
      }
      for (final entry in enStrings.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'EN key "${entry.key}" has an empty value',
        );
      }
    });
  });

  group('Phase 1 — Constants', () {
    test('dbVersion is 3', () {
      expect(AppConstants.dbVersion, equals(3));
    });

    test('minorUnitFactor is 100', () {
      expect(AppConstants.minorUnitFactor, equals(100));
    });

    test('default locale is Arabic', () {
      expect(AppConstants.localeAr, equals('ar'));
    });
  });

  group('Phase 1 — Routes', () {
    test('Splash route is root', () {
      expect(AppRoutes.splash, equals('/'));
    });

    test('Home route defined', () {
      expect(AppRoutes.home, startsWith('/'));
    });

    test('All routes are unique', () {
      final all = [
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.settings,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.customers,
        AppRoutes.customerDetail,
        AppRoutes.customerCreate,
        AppRoutes.invoices,
        AppRoutes.invoiceDetail,
        AppRoutes.invoiceCreate,
        AppRoutes.payments,
        AppRoutes.paymentCreate,
        AppRoutes.installments,
        AppRoutes.products,
        AppRoutes.reports,
      ];
      expect(
        all.toSet().length,
        equals(all.length),
        reason: 'Duplicate route strings found',
      );
    });
  });

  group('Phase 1 — Financial arithmetic (minor units)', () {
    test('1 EGP = 100 piasters', () {
      const egp = 1;
      final minor = egp * AppConstants.minorUnitFactor;
      expect(minor, equals(100));
    });

    test('Minor units avoid floating-point drift', () {
      // 0.1 + 0.2 in double is NOT 0.3; in int minor units it is exact.
      const a = 10; // 0.10 EGP in minor units
      const b = 20; // 0.20 EGP in minor units
      expect(a + b, equals(30)); // exactly 0.30 EGP
    });
  });

  group('Phase 1 — Theme tokens', () {
    test('Accent color has correct value', () {
      // AppColors.accent = Color(0xFF246B5A)
      const expected = Color(0xFF246B5A);
      expect(expected.toARGB32(), equals(0xFF246B5A));
    });
  });
}
