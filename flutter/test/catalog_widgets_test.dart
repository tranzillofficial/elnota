import 'package:elnota/features/products/repositories/catalog_repository.dart';
import 'package:elnota/features/products/models/catalog_models.dart';
import 'package:elnota/features/products/controllers/catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:elnota/app/theme/app_theme.dart';
import 'package:elnota/core/services/account_access_service.dart';
import 'package:elnota/features/products/views/products_view.dart';

class _Access extends AccountAccessService {
  _Access() : super(automaticallyRefresh: false);
}

class _Catalog extends CatalogRepository {
  @override
  Stream<List<ProductCategory>> watchCategories() => Stream.value(const [
    ProductCategory(id: 'a', name: 'أجهزة'),
    ProductCategory(id: 'b', name: 'ورق'),
  ]);
  @override
  Stream<List<CatalogProduct>> watchProducts() => Stream.value(const [
    CatalogProduct(
      id: '1',
      categoryId: 'a',
      categoryName: 'أجهزة',
      barcode: '00123',
      name: 'طابعة',
      priceMinor: 200000,
    ),
    CatalogProduct(
      id: '2',
      categoryId: 'b',
      categoryName: 'ورق',
      barcode: '00456',
      name: 'ورق حراري',
      priceMinor: 10000,
    ),
  ]);
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('catalog search and category filtering RTL at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final access = _Access();
      access.access.value = const AccountAccess(
        active: true,
        catalogOverride: true,
      );
      Get.put<AccountAccessService>(access);
      final controller = CatalogController(repository: _Catalog());
      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ProductsView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('طابعة'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '00456');
      await tester.pumpAndSettle();
      expect(find.text('ورق حراري'), findsOneWidget);
      expect(find.text('طابعة'), findsNothing);
      await tester.enterText(find.byType(TextField), 'أجهزة');
      await tester.pumpAndSettle();
      expect(find.text('طابعة'), findsOneWidget);
      expect(find.text('ورق حراري'), findsNothing);
      access.access.value = const AccountAccess();
      await tester.pumpAndSettle();
      expect(find.text('طابعة'), findsNothing);
      expect(find.text('تحديث صلاحيات الحساب'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      Get.reset();
    });
  }
}
