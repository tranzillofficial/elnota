import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/services/backup_import_plan.dart';
import 'package:elnota/core/sync/models/cloud_snapshot.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';

Map<String, dynamic> clone(Map<String, dynamic> s) =>
    jsonDecode(jsonEncode(s)) as Map<String, dynamic>;
Map<String, dynamic> base() {
  final legacy = {
    'schemaVersion': 1,
    'updatedAt': '2026-10-25T10:00:00Z',
    'settings': {
      'businessName': 'test',
      'phone': '',
      'address': '',
      'currency': 'جنيه',
    },
    'customers': [
      {'id': 'c', 'name': 'test', 'phone': '', 'address': '', 'notes': ''},
    ],
    'products': [],
    'invoices': [
      {
        'id': 'i',
        'number': 'INV-OLD',
        'customerId': 'c',
        'date': '2026-10-01',
        'dueDate': '',
        'notes': '',
        'method': 'credit',
        'lines': [
          {'name': 'line', 'productId': '', 'price': 150, 'quantity': 1},
        ],
        'payments': [
          {'id': 'p', 'amount': 50, 'date': '2026-10-01', 'note': ''},
        ],
      },
    ],
  };
  final plan = BackupImportPlan.parse(jsonEncode(legacy));
  return {'schema_version': 3, ...plan.tables};
}

Map<String, dynamic> paid(Map<String, dynamic> s, String id, int amount) {
  final n = clone(s),
      p = Map<String, dynamic>.from((s['payments'] as List).first as Map),
      l = Map<String, dynamic>.from(
        (s['ledger_entries'] as List).firstWhere(
              (r) => r['event_type'] == 'payment_receipt',
            )
            as Map,
      );
  (n['payments'] as List).add({
    ...p,
    'id': id,
    'idempotency_key': id,
    'amount_minor': amount,
  });
  (n['ledger_entries'] as List).add({
    ...l,
    'id': 'ledger-$id',
    'source_id': id,
    'amount_minor': -amount,
  });
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('two devices independent payments survive merge with exact balance', () {
    final b = base(), l = paid(b, 'left', 1000), r = paid(b, 'right', 1500);
    final merged = CloudSnapshot.merge(baseline: b, local: l, remote: r);
    final p = BackupImportPlan.parse(jsonEncode(merged));
    expect(p.count('payments'), 3);
    expect(p.balanceMinor, 7500);
  });
  test('lost server response and replay never doubles a receipt', () {
    final b = base(), l = paid(b, 'same', 1000);
    final merged = CloudSnapshot.merge(baseline: b, local: l, remote: clone(l));
    expect(BackupImportPlan.parse(jsonEncode(merged)).count('payments'), 2);
    expect(BackupImportPlan.parse(jsonEncode(merged)).balanceMinor, 9000);
  });
  test('concurrent contact edits require explicit resolution', () {
    final b = base(), l = clone(b), r = clone(b);
    (l['customers'] as List).single['name'] = 'left';
    (r['customers'] as List).single['name'] = 'right';
    expect(
      () => CloudSnapshot.merge(baseline: b, local: l, remote: r),
      throwsA(isA<CloudConflict>()),
    );
  });
  test('server-only contact change merges with independent local receipt', () {
    final b = base(), l = paid(b, 'receipt', 500), r = clone(b);
    (r['customers'] as List).single['phone'] = '012';
    final m = CloudSnapshot.merge(baseline: b, local: l, remote: r);
    expect((m['customers'] as List).single['phone'], '012');
    expect(BackupImportPlan.parse(jsonEncode(m)).balanceMinor, 9500);
  });
  test('physical removal of baseline history aborts merge', () {
    final b = base(), l = clone(b);
    (l['payments'] as List).clear();
    expect(
      () => CloudSnapshot.merge(baseline: b, local: l, remote: b),
      throwsA(isA<CloudConflict>()),
    );
  });
  test('malformed ledger is rejected before local apply', () {
    final b = base(), l = paid(b, 'bad', 500);
    (l['ledger_entries'] as List).last['amount_minor'] = -1;
    expect(
      () => CloudSnapshot.merge(baseline: b, local: l, remote: b),
      throwsFormatException,
    );
  });
  test('manual amount snapshots need no fake item row', () {
    final b = base();
    (b['invoice_items'] as List).clear();
    (b['invoices'] as List).single['is_manual_amount'] = 1;
    expect(BackupImportPlan.parse(jsonEncode(b)).balanceMinor, 10000);
  });
  test(
    'local transaction racing a pull is preserved, then checkpoint is atomic',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final d = AppDao(db);
      await d.createTables();
      final b = base();
      await d.importBackup(BackupImportPlan.parse(jsonEncode(b)));
      await d.cloudBaseline();
      final captured = CloudSnapshot.normalize(await d.exportLocalSnapshot());
      await d.addPayment(
        customerId: 'c',
        amountMinor: 500,
        idempotencyKey: 'offline-new',
      );
      await expectLater(
        d.applyCloudSnapshot(
          expectedLocal: captured,
          merged: paid(b, 'remote', 100),
        ),
        throwsStateError,
      );
      expect(
        BackupImportPlan.parse(
          jsonEncode(await d.exportLocalSnapshot()),
        ).balanceMinor,
        9500,
      );
      final raw = await d.exportLocalSnapshot();
      final local = CloudSnapshot.normalize(raw);
      final merged = CloudSnapshot.merge(
        baseline: b,
        local: local,
        remote: paid(b, 'remote', 100),
      );
      await d.applyCloudSnapshot(expectedLocal: local, merged: merged);
      expect(
        BackupImportPlan.parse(
          jsonEncode(await d.exportLocalSnapshot()),
        ).balanceMinor,
        9400,
      );
      final ids = (raw['sync_outbox'] as List)
          .map((r) => r['operation_id'] as String)
          .toList();
      await d.saveCloudBaseline(merged, 2, ids);
      expect((await d.cloudBaseline())!['revision'], 2);
      expect((await d.getPendingOutbox()), isEmpty);
      expect((await d.exportLocalSnapshot())['import_archives'], isNotEmpty);
      await db.close();
    },
  );
}
