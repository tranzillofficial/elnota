import 'package:elnota/app/routes/app_pages.dart';
import 'package:elnota/app/theme/app_theme.dart';
import 'package:elnota/core/services/account_access_service.dart';
import 'package:elnota/core/services/supabase_service.dart';
import 'package:elnota/core/utils/app_routes.dart';
import 'package:elnota/core/utils/backend_config.dart';
import 'package:elnota/features/auth/services/auth_service.dart';
import 'package:elnota/features/auth/views/account_approval_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:elnota/features/auth/services/auth_destination.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  test(
    'verified admin goes to dashboard without a merchant subscription',
    () async {
      expect(
        await AuthDestination(isAdmin: () async => true).resolve(),
        AppRoutes.admin,
      );
      expect(
        await AuthDestination(isAdmin: () async => false).resolve(),
        AppRoutes.home,
      );
      expect(
        await AuthDestination(
          isAdmin: () async => throw StateError('offline'),
        ).resolve(),
        AppRoutes.home,
      );
    },
  );

  testWidgets('admin opening home never sees the payment activation form', (
    tester,
  ) async {
    Get.put(SupabaseService());
    Get.put(AuthService());
    final access = Get.put(AccountAccessService(automaticallyRefresh: false));
    access.resolved.value = true;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.admin,
            page: () => const Scaffold(body: Text('admin-dashboard')),
          ),
        ],
        home: AccountApprovalGate(
          destination: AuthDestination(isAdmin: () async => true),
          child: const Scaffold(body: Text('merchant-ledger')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.admin);
    expect(find.text('admin-dashboard'), findsOneWidget);
    expect(find.text('تفعيل حساب ElNota'), findsNothing);
    expect(find.text('merchant-ledger'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('native launch never creates an anonymous local owner', () {
    Get.put(SupabaseService());
    final auth = Get.put(AuthService());
    expect(auth.isAuthenticated, false);
    expect(auth.currentSession.value, isNull);
    expect(SessionGuard().redirect(AppRoutes.home)?.name, AppRoutes.login);
  });

  test('failed authentication cannot grant local use', () async {
    Get.put(SupabaseService());
    final auth = Get.put(AuthService());
    expect(
      await auth.signIn(
        email: 'test@example.invalid',
        password: 'test-password',
      ),
      false,
    );
    expect(
      await auth.signUp(
        email: 'test@example.invalid',
        password: 'test-password',
        storeName: 'Test',
      ),
      false,
    );
    expect(auth.currentSession.value, isNull);
    expect(auth.lastError.value, isNotEmpty);
  });

  test('all builds carry the same public backend configuration', () {
    expect(
      Uri.parse(BackendConfig.url).host,
      'fsmoerttftxcuxpswufk.supabase.co',
    );
    expect(BackendConfig.publishableKey, startsWith('sb_publishable_'));
  });

  test('suspended or deleted accounts never retain active entitlement', () {
    for (final field in ['suspended_at', 'deleted_at']) {
      expect(
        AccountAccess.fromMap({
          'activated_at': '2026-10-01',
          field: '2026-10-24',
        }).active,
        false,
      );
    }
    expect(AccountAccess.fromMap({}).active, false);
  });

  for (final active in [false, true]) {
    testWidgets('merchant content requires approved entitlement: $active', (
      tester,
    ) async {
      Get.put(SupabaseService());
      Get.put(AuthService());
      final access = Get.put(AccountAccessService(automaticallyRefresh: false));
      access.resolved.value = true;
      access.access.value = AccountAccess(active: active);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: AccountApprovalGate(
              child: Scaffold(body: Text('protected-account')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('protected-account'),
        active ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('تفعيل حساب ElNota'),
        active ? findsNothing : findsOneWidget,
      );
      if (active) {
        // Revocation blocks an already-open screen without waiting for navigation.
        access.access.value = const AccountAccess();
        await tester.pumpAndSettle();
        expect(find.text('protected-account'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
