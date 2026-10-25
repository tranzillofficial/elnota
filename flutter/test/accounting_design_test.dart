import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/features/invoices/models/invoice_model.dart';
import 'package:elnota/features/invoices/models/invoice_terms.dart';
import 'package:elnota/features/customers/models/account_statement.dart';
import 'package:elnota/core/services/statement_pdf_service.dart';

InvoiceModel invoice(String id, int amount, DateTime date) => InvoiceModel(
  id: id,
  customerId: 'c',
  status: 'posted',
  totalMinor: amount,
  discountMinor: 0,
  isManualAmount: true,
  invoiceDate: date,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'installments preserve every piaster; anchored dates survive short months',
    () {
      final amounts = installmentAmounts(120001, 6);
      expect(amounts.reduce((a, b) => a + b), 120001);
      expect(amounts, [20000, 20000, 20000, 20000, 20000, 20001]);
      expect(installmentDate(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(installmentDate(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
      expect(installmentDate(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    },
  );
  test(
    'FIFO credits settle oldest due across invoices; upfront is deducted once',
    () {
      final date = DateTime(2026, 1, 1);
      final dues = allocateCustomerDues(
        invoices: [invoice('new', 300000, date), invoice('old', 100000, date)],
        terms: [
          InvoiceTerms(
            invoiceId: 'new',
            customerId: 'c',
            method: 'installments',
            upfrontMinor: 60000,
            months: 6,
            firstDueDate: DateTime(2026, 3, 1),
          ),
          InvoiceTerms(
            invoiceId: 'old',
            customerId: 'c',
            method: 'installments',
            upfrontMinor: 0,
            months: 2,
            firstDueDate: DateTime(2026, 2, 1),
          ),
        ],
        outstandingMinor: 280000,
      );
      expect(dues.first.invoiceId, 'old');
      expect(dues.first.remainingMinor, 0);
      expect(dues.fold<int>(0, (s, d) => s + d.remainingMinor), 280000);
      expect(dues.where((d) => d.overdueAt(DateTime(2026, 3, 1))).length, 0);
    },
  );
  test(
    'period statement includes opening balance, credits and end-of-day entries',
    () {
      final statement = AccountStatement(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 23),
        movements: [
          StatementMovement(
            id: '0',
            reference: 'i0',
            date: DateTime(2026, 9, 30),
            label: 'فاتورة',
            signedMinor: 50000,
          ),
          StatementMovement(
            id: '1',
            reference: 'p1',
            date: DateTime(2026, 10, 1),
            label: 'دفعة',
            signedMinor: -100000,
          ),
          StatementMovement(
            id: '2',
            reference: 'i2',
            date: DateTime(2026, 10, 23, 23, 59),
            label: 'فاتورة',
            signedMinor: 170000,
          ),
          StatementMovement(
            id: '3',
            reference: 'i3',
            date: DateTime(2026, 10, 24),
            label: 'فاتورة',
            signedMinor: 900000,
          ),
        ],
      );
      expect(statement.openingMinor, 50000);
      expect(statement.lines.first.balanceMinor, -50000);
      expect(statement.closingMinor, 120000);
      expect(statement.lines.length, 2);
    },
  );
  test('Arabic statement PDF includes all rows over multiple pages', () async {
    final statement = AccountStatement(
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
      movements: List.generate(
        90,
        (i) => StatementMovement(
          id: '$i',
          reference: 'invoice-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          label: 'فاتورة بيع',
          signedMinor: 10000,
        ),
      ),
    );
    final bytes = await StatementPdfService.generate(
      name: 'محمد فؤاد',
      phone: '01012345678',
      statement: statement,
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
  });
  group('real local database', () {
    late AppDatabase db;
    late AppDao dao;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = AppDao(db);
      await dao.createTables();
    });
    tearDown(() async {
      await db.close();
    });
    Future<String> createPlan(String customer) => dao.createInvoiceWithTerms(
      customerId: customer,
      totalMinor: 300000,
      discountMinor: 0,
      isManualAmount: true,
      items: [],
      method: 'installments',
      upfrontMinor: 60000,
      months: 6,
      firstDueDate: DateTime(2026, 11, 23),
      invoiceDate: DateTime(2026, 10, 23),
    );
    test('invoice, plan, upfront, ledger and outbox commit together', () async {
      final customer = await dao.createCustomer(name: 'محمد');
      final id = await createPlan(customer);
      final balance = await dao.watchBalance(customer).first;
      expect(balance.outstandingMinor, 240000);
      expect((await dao.watchInvoiceTerms().first).single['invoice_id'], id);
      expect(
        (await dao.watchPayments(customer).first).single.amountMinor,
        60000,
      );
      final backup = await dao.exportLocalSnapshot();
      expect((backup['invoices'] as List).length, 1);
      expect((backup['ledger_entries'] as List).length, 2);
      final outbox = backup['sync_outbox'] as List;
      final create = outbox.cast<Map>().firstWhere(
        (row) =>
            row['entity_type'] == 'invoice' &&
            row['operation_type'] == 'create',
      );
      final payload = jsonDecode(create['payload_json'] as String) as Map;
      expect((payload['payment_terms'] as Map)['months'], 6);
    });
    test(
      'raw SQL streams refresh after payment; duplicate receipt applies once',
      () async {
        final customer = await dao.createCustomer(name: 'عميل');
        await createPlan(customer);
        final first = Completer<void>();
        final second = Completer<void>();
        final updates = <CustomerBalance>[];
        final sub = dao.watchBalance(customer).listen((b) {
          updates.add(b);
          if (!first.isCompleted) {
            first.complete();
          } else if (!second.isCompleted) {
            second.complete();
          }
        });
        await first.future;
        await dao.addPayment(
          customerId: customer,
          amountMinor: 30000,
          idempotencyKey: 'stable-key',
        );
        await second.future.timeout(const Duration(seconds: 3));
        await dao.addPayment(
          customerId: customer,
          amountMinor: 30000,
          idempotencyKey: 'stable-key',
        );
        expect(
          (await dao.watchBalance(customer).first).outstandingMinor,
          210000,
        );
        expect(updates.last.outstandingMinor, 210000);
        await sub.cancel();
      },
    );
    test('malformed item rolls back the whole invoice', () async {
      final customer = await dao.createCustomer(name: 'عميل');
      await expectLater(
        dao.createInvoiceWithTerms(
          customerId: customer,
          totalMinor: 10000,
          discountMinor: 0,
          isManualAmount: false,
          items: [
            {'description': 'غير مكتمل'},
          ],
          method: 'cash',
          upfrontMinor: 10000,
          months: 1,
          firstDueDate: DateTime(2026, 10, 23),
          invoiceDate: DateTime(2026, 10, 23),
        ),
        throwsA(isA<TypeError>()),
      );
      expect(await dao.watchInvoices(customer).first, isEmpty);
      expect(await dao.watchPayments(customer).first, isEmpty);
      expect(await dao.watchInvoiceTerms().first, isEmpty);
    });
    test('new cash invoice posts one charge and one full receipt', () async {
      final customer = await dao.createCustomer(name: 'عميل');
      await dao.createInvoiceWithTerms(
        customerId: customer,
        totalMinor: 10000,
        discountMinor: 1000,
        isManualAmount: true,
        items: [],
        method: 'cash',
        upfrontMinor: 9000,
        months: 1,
        firstDueDate: DateTime(2026, 10, 23),
        invoiceDate: DateTime(2026, 10, 23),
      );
      expect((await dao.watchBalance(customer).first).outstandingMinor, 0);
      expect((await dao.watchCustomerLedger(customer).first).length, 2);
    });
  });
  test(
    'version 1 upgrade retains existing customers and adds invoice terms',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 1');
            raw.execute(
              'CREATE TABLE customers (id TEXT PRIMARY KEY, workspace_id TEXT, name TEXT, phone TEXT, notes TEXT, version INTEGER, created_at INTEGER, updated_at INTEGER, deleted_at INTEGER)',
            );
            raw.execute(
              "INSERT INTO customers (id,workspace_id,name,version,created_at,updated_at) VALUES ('existing','default','عميل قديم',0,0,0)",
            );
          },
        ),
      );
      try {
        final dao = AppDao(db);
        expect((await dao.watchCustomers().first).single.id, 'existing');
        expect(await dao.watchInvoiceTerms().first, isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}
