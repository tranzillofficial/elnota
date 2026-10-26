import 'package:elnota/features/admin/views/admin_account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('service controls remain visible at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAccountCard(
                account: {
                  'user_id': 'merchant',
                  'email': 'merchant@example.test',
                  'business_name': 'نشاط تجريبي',
                  'activated_at': '2026-10-01',
                  'cloud_until': DateTime.now()
                      .add(const Duration(days: 30))
                      .toIso8601String(),
                  'catalog_enabled': false,
                  'printing_enabled': true,
                },
                enabled: true,
                onAction: (value) async {
                  selected = value;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('تفعيل / تجديد الكلاود شهريًا'), findsOneWidget);
      expect(find.text('تفعيل / تجديد الكلاود سنويًا'), findsOneWidget);
      expect(find.text('إيقاف الكلاود'), findsOneWidget);
      expect(find.text('تفعيل المخزون'), findsOneWidget);
      expect(find.text('إيقاف الطباعة'), findsOneWidget);
      expect(find.text('إيقاف الحساب'), findsOneWidget);
      await tester.tap(find.text('تفعيل المخزون'));
      expect(selected, 'catalog_on');
      expect(tester.takeException(), isNull);
    });
  }
}
