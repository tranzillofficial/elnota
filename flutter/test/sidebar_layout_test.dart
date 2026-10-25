import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/widgets/design_widgets.dart';

void main() {
  testWidgets('compact sidebar fits short viewport and exposes account menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(986, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              DesignSidebar(selected: 0, onSelect: (_) {}),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets(
    'admin navigation has platform sections instead of merchant sections',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DesignSidebar(admin: true, selected: 0, onSelect: (_) {}),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      expect(find.byTooltip('الإصدارات والتحميلات'), findsOneWidget);
      expect(find.byTooltip('إعدادات المنصة'), findsOneWidget);
      expect(find.byTooltip('الفواتير'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
