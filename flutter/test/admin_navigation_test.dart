import 'package:elnota/app/theme/app_theme.dart';
import 'package:elnota/features/admin/repositories/admin_repository.dart';
import 'package:elnota/features/admin/views/admin_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Admin implements AdminGateway {
  int roleChecks = 0;
  @override
  Future<bool> isAdmin() async {
    roleChecks++;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> accounts(int page) async => [];
  @override
  Future<List<Map<String, dynamic>>> requests(int page) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'replacing admin route does not reuse a disposed loading controller',
    (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardView(gateway: _Admin()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لوحة الإدارة'), findsOneWidget);
      final replacement = _Admin();
      Get.offAll(() => AdminDashboardView(gateway: replacement));
      await tester.pumpAndSettle();
      expect(find.text('لوحة الإدارة'), findsOneWidget);
      expect(replacement.roleChecks, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
