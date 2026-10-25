import 'dart:convert';
import 'package:drift/native.dart';
import 'package:imcodec/imcodec.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/core/services/backup_import_plan.dart';

Map<String, dynamic> legacy() => {
  'schemaVersion': 1,
  'updatedAt': '2026-10-25T10:00:00Z',
  'settings': {
    'businessName': 'اختبار',
    'phone': '',
    'address': '',
    'currency': 'جنيه',
  },
  'customers': [
    {
      'id': 'c1',
      'name': 'عميل',
      'phone': '010',
      'address': 'القاهرة',
      'notes': 'ملاحظة',
    },
  ],
  'products': [
    {
      'id': 'p1',
      'name': 'منتج',
      'barcode': '00123',
      'price': 10,
      'category': 'قسم',
    },
  ],
  'invoices': [
    {
      'id': 'i1',
      'number': 'OLD-001',
      'customerId': 'c1',
      'date': '2026-10-01',
      'dueDate': '2026-11-01',
      'notes': '',
      'method': 'installment',
      'lines': [
        {'name': 'منتج', 'productId': 'p1', 'quantity': 1.5, 'price': 100},
      ],
      'payments': [
        {'id': 'r1', 'amount': 50, 'date': '2026-10-01', 'note': ''},
      ],
      'installmentPlan': {
        'months': 2,
        'financedAmount': 100,
        'firstDueDate': '2026-11-01',
      },
    },
    {
      'id': 'void',
      'number': 'OLD-002',
      'customerId': 'c1',
      'date': '2026-10-02',
      'dueDate': '',
      'notes': 'ملغاة',
      'method': 'cash',
      'voided': true,
      'lines': [
        {'name': 'قديم', 'productId': '', 'quantity': 1, 'price': 500},
      ],
      'payments': [
        {'id': 'r2', 'amount': 500, 'date': '2026-10-02', 'note': ''},
      ],
    },
  ],
  'customerPayments': [
    {
      'id': 'account-r',
      'customerId': 'c1',
      'amount': 25,
      'date': '2026-10-03',
      'note': 'دفعة عامة',
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy totals, credit, void history, fractional item and barcode survive',
    () {
      final p = BackupImportPlan.parse(
        jsonEncode({'application': 'ElNota', 'data': legacy()}),
      );
      expect(p.balanceMinor, 7500);
      expect(p.count('invoices'), 2);
      expect(p.count('payments'), 2);
      expect(p.tables['invoice_items']!.first['unit_price_minor'], 15000);
      expect(p.tables['invoice_items']!.first['description'], contains('1.5'));
      expect(p.tables['customers']!.single['notes'], contains('القاهرة'));
      expect(p.tables['catalog_products']!.single['barcode'], '00123');
      expect(p.tables['invoice_terms']!.single['upfront_minor'], 5000);
      expect(p.tables['invoices']!.last['status'], 'voided');
    },
  );
  test('import is atomic, idempotent and new backup can be restored', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = AppDao(db);
    await dao.createTables();
    final plan = BackupImportPlan.parse(jsonEncode(legacy()));
    expect(await dao.importBackup(plan), true);
    expect(await dao.importBackup(plan), false);
    final snapshot = await dao.exportLocalSnapshot();
    final restored = BackupImportPlan.parse(jsonEncode(snapshot));
    expect(restored.balanceMinor, 7500);
    expect(restored.count('invoices'), 2);
    final db2 = AppDatabase(NativeDatabase.memory());
    final dao2 = AppDao(db2);
    await dao2.createTables();
    expect(await dao2.importBackup(restored), true);
    expect(
      (await dao2.exportLocalSnapshot())['payments'],
      snapshot['payments'],
    );
    final different = legacy();
    different['updatedAt'] = '2026-10-26T10:00:00Z';
    await expectLater(
      dao.importBackup(BackupImportPlan.parse(jsonEncode(different))),
      throwsStateError,
    );
    expect((await dao.exportLocalSnapshot())['invoices'], snapshot['invoices']);
    await db.close();
    await db2.close();
  });
  test(
    'reject wrong owner, missing customer and tampered ledger before writing',
    () async {
      final p = BackupImportPlan.parse(jsonEncode(legacy()));
      final db = AppDatabase(NativeDatabase.memory());
      final dao = AppDao(db);
      await dao.createTables();
      await dao.importBackup(p);
      final snapshot = await dao.exportLocalSnapshot();
      snapshot['owner_id'] = 'other';
      expect(
        () => BackupImportPlan.parse(jsonEncode(snapshot), accountId: 'me'),
        throwsFormatException,
      );
      snapshot.remove('owner_id');
      (snapshot['ledger_entries'] as List).first['amount_minor'] = 1;
      expect(
        () => BackupImportPlan.parse(jsonEncode(snapshot)),
        throwsFormatException,
      );
      final bad = legacy();
      (bad['invoices'] as List).first['customerId'] = 'missing';
      expect(
        () => BackupImportPlan.parse(jsonEncode(bad)),
        throwsFormatException,
      );
      await db.close();
    },
  );
  test('advance is retained as negative balance; no clamping', () {
    final d = legacy();
    (d['customerPayments'] as List).single['amount'] = 200;
    expect(BackupImportPlan.parse(jsonEncode(d)).balanceMinor, -10000);
  });
  test(
    'database constraint failure rolls back all inserted rows and archive',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = AppDao(db);
      await dao.createTables();
      final p = BackupImportPlan.parse(jsonEncode(legacy()));
      p.tables['catalog_products']!.add({
        ...p.tables['catalog_products']!.single,
        'id': 'duplicate-barcode',
      });
      await expectLater(dao.importBackup(p), throwsA(anything));
      final s = await dao.exportLocalSnapshot();
      expect(s['customers'], isEmpty);
      expect(s['invoices'], isEmpty);
      p.tables['catalog_products']!.removeLast();
      expect(await dao.importBackup(p), true);
      await db.close();
    },
  );
  test(
    'legacy product image becomes WebP while source remains recoverable',
    () async {
      final data = legacy();
      final original =
          'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 2, height: 2)))}';
      (data['products'] as List).single['image'] = original;
      final plan = BackupImportPlan.parse(jsonEncode(data));
      await plan.prepareLegacyImages();
      final bytes = base64Decode(
        plan.tables['catalog_products']!.single['image_webp'] as String,
      );
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WEBP');
      expect((plan.source['products'] as List).single['image'], original);
    },
  );
}
