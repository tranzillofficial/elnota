import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/core/services/account_access_service.dart';
import 'package:elnota/core/services/daily_backup_service.dart';
import 'package:elnota/core/services/product_image_service.dart';
import 'package:imcodec/imcodec.dart' as codec;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cloud and explicit catalog grant are independent and expire precisely',
    () {
      final now = DateTime.utc(2026, 10, 23);
      final cloud = AccountAccess(
        active: true,
        cloudUntil: now.add(const Duration(days: 1)),
      );
      expect(cloud.cloudAt(now), true);
      expect(cloud.catalogAt(now), true);
      expect(cloud.cloudAt(now.add(const Duration(days: 1))), false);
      const override = AccountAccess(active: true, catalogOverride: true);
      expect(override.catalogAt(now), true);
      expect(override.cloudAt(now), false);
      expect(const AccountAccess(catalogOverride: true).catalogAt(now), false);
    },
  );
  test('midnight due persists until acknowledged; missed days coalesce', () {
    expect(
      DailyBackupPolicy.due(DateTime(2026, 10, 23, 23, 59), '2026-10-23'),
      false,
    );
    expect(DailyBackupPolicy.due(DateTime(2026, 10, 24), '2026-10-23'), true);
    expect(DailyBackupPolicy.due(DateTime(2026, 10, 27), '2026-10-23'), true);
    expect(DailyBackupPolicy.due(DateTime(2026, 10, 24), '2026-10-24'), false);
    expect(DailyBackupService.backendEnabled, false);
  });
  test(
    'catalog survives v2 upgrade, duplicate codes rollback, archive keeps rows',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 2');
            raw.execute(
              'CREATE TABLE customers(id TEXT PRIMARY KEY,workspace_id TEXT,name TEXT,phone TEXT,notes TEXT,version INTEGER,created_at INTEGER,updated_at INTEGER,deleted_at INTEGER)',
            );
            raw.execute(
              "INSERT INTO customers(id,workspace_id,name,version,created_at,updated_at) VALUES('old','default','عميل قديم',0,0,0)",
            );
          },
        ),
      );
      final dao = AppDao(db);
      addTearDown(db.close);
      await dao.createTables();
      expect((await dao.watchCustomer('old').first)!.name, 'عميل قديم');
      await dao.saveCategory(name: 'أجهزة');
      final category = (await dao.watchCategories().first).single;
      await dao.saveProduct(
        categoryId: category.id,
        barcode: '000123',
        name: 'طابعة',
        priceMinor: 200001,
      );
      final product = (await dao.watchProducts().first).single;
      expect(product.barcode, '000123');
      expect(product.priceMinor, 200001);
      final before = (await dao.getPendingOutbox()).length;
      await expectLater(
        dao.saveProduct(
          categoryId: category.id,
          barcode: '000123',
          name: 'مكرر',
          priceMinor: 50,
        ),
        throwsA(anything),
      );
      expect((await dao.getPendingOutbox()).length, before);
      await expectLater(
        dao.archiveCatalog(category.id, category: true),
        throwsStateError,
      );
      final changes = dao.watchProducts().skip(1).first;
      await dao.saveProduct(
        id: product.id,
        categoryId: category.id,
        barcode: '000124',
        name: 'طابعة معدلة',
        priceMinor: 100,
      );
      expect((await changes).single.name, 'طابعة معدلة');
      final snapshot = await dao.exportLocalSnapshot();
      expect(snapshot['catalog_products'], hasLength(1));
      expect(snapshot['schema_version'], 3);
      await dao.archiveCatalog(product.id);
      expect(await dao.watchProducts().first, isEmpty);
      expect(
        (await db.customSelect('SELECT deleted_at FROM catalog_products').get())
            .single
            .data['deleted_at'],
        isNotNull,
      );
      await dao.archiveCatalog(category.id, category: true);
      expect(await dao.watchCategories().first, isEmpty);
    },
  );
  test(
    'compression creates decodable WebP within size and pixel limits',
    () async {
      final source = codec.Image(width: 1200, height: 600);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgba(x, y, x % 256, y % 256, 100, 255);
        }
      }
      final result = await ProductImageService.compress(
        codec.encodePng(source),
      );
      expect(ascii.decode(result.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(result.sublist(8, 12)), 'WEBP');
      expect(result.length, lessThanOrEqualTo(512 * 1024));
      final decoded = codec.decodeWebP(result);
      expect(decoded.width, 960);
      expect(decoded.height, 480);
    },
  );
}
