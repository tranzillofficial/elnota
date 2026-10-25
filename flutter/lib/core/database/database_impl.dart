import 'dart:convert';
import '../services/backup_import_plan.dart';
import '../sync/models/cloud_snapshot.dart';
import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../features/products/models/catalog_models.dart';

part 'catalog_dao.dart';
part 'cloud_dao.dart';

// ─── Domain Models ───────────────────────────────────────────────────────────

class CustomerRow {
  const CustomerRow({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.phone,
    this.notes,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final String workspaceId;
  final String name;
  final String? phone;
  final String? notes;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class InvoiceRow {
  const InvoiceRow({
    required this.id,
    required this.workspaceId,
    required this.customerId,
    this.customerName,
    this.invoiceNumber,
    required this.status,
    required this.totalMinor,
    required this.discountMinor,
    this.notes,
    required this.isManualAmount,
    required this.invoiceDate,
    this.dueDate,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final String workspaceId;
  final String customerId;
  final String? customerName;
  final String? invoiceNumber;
  final String status;
  final int totalMinor;
  final int discountMinor;
  final String? notes;
  final bool isManualAmount;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Net amount after discount
  int get netMinor => totalMinor - discountMinor;
}

class InvoiceItemRow {
  const InvoiceItemRow({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
    required this.discountMinor,
    required this.createdAt,
  });
  final String id;
  final String invoiceId;
  final String? productId;
  final String description;
  final int quantity;
  final int unitPriceMinor;
  final int discountMinor;
  final DateTime createdAt;

  int get lineTotal => quantity * unitPriceMinor - discountMinor;
}

class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.workspaceId,
    required this.customerId,
    this.customerName,
    required this.amountMinor,
    this.notes,
    required this.paymentDate,
    required this.idempotencyKey,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final String workspaceId;
  final String customerId;
  final String? customerName;
  final int amountMinor;
  final String? notes;
  final DateTime paymentDate;
  final String idempotencyKey;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class WorkspaceStats {
  const WorkspaceStats({
    required this.customersCount,
    required this.invoicesCount,
    required this.paymentsCount,
    required this.totalInvoicedMinor,
    required this.totalCollectedMinor,
  });

  final int customersCount;
  final int invoicesCount;
  final int paymentsCount;
  final int totalInvoicedMinor;
  final int totalCollectedMinor;

  int get totalReceivablesMinor => totalInvoicedMinor - totalCollectedMinor;
}

class RecentActivityItem {
  const RecentActivityItem({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.amountMinor,
    required this.date,
    this.notes,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String type; // 'invoice' or 'payment'
  final int amountMinor;
  final DateTime date;
  final String? notes;

  bool get isInvoice => type == 'invoice';
  bool get isPayment => type == 'payment';
}

class LedgerEntryRow {
  final String? reference;
  const LedgerEntryRow({
    this.reference,
    required this.id,
    required this.workspaceId,
    required this.customerId,
    required this.sourceId,
    required this.eventType,
    required this.amountMinor,
    this.notes,
    required this.occurredAt,
    required this.createdAt,
  });
  final String id;
  final String workspaceId;
  final String customerId;
  final String sourceId;
  final String eventType;
  final int amountMinor;
  final String? notes;
  final DateTime occurredAt;
  final DateTime createdAt;
}

class CustomerBalance {
  const CustomerBalance({
    required this.customerId,
    required this.totalInvoicedMinor,
    required this.totalDiscountsMinor,
    required this.totalPaymentsMinor,
    required this.totalAdjustmentsMinor,
  });
  final String customerId;
  final int totalInvoicedMinor;
  final int totalDiscountsMinor;
  final int totalPaymentsMinor;
  final int totalAdjustmentsMinor;

  /// Positive = customer owes; negative = customer has credit.
  int get outstandingMinor =>
      totalInvoicedMinor -
      totalDiscountsMinor -
      totalPaymentsMinor -
      totalAdjustmentsMinor;
}

// ─── Database DAO ────────────────────────────────────────────────────────────

/// All DB access goes through this class.
/// Uses [customSelect] / [customInsert] / [customUpdate] to bypass
/// the missing drift_dev code-gen step.
class AppDao {
  AppDao(this._db);
  final GeneratedDatabase _db;
  final _uuid = const Uuid();

  String get _wsId => 'default'; // Phase 3 will inject real workspace id

  // ──────────────────────────────────────────────────────────────────────────
  // Customers
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>>
  exportLocalSnapshot() => _db.transaction(() async {
    final snapshot = <String, dynamic>{
      'schema_version': 3,
      'workspace_id': _wsId,
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final table in [
      'customers',
      'invoices',
      'payments',
      'ledger_entries',
      'invoice_terms',
      'sync_outbox',
      'product_categories',
      'catalog_products',
    ]) {
      snapshot[table] =
          (await _db
                  .customSelect(
                    'SELECT * FROM $table WHERE workspace_id = ?',
                    variables: [Variable.withString(_wsId)],
                  )
                  .get())
              .map((r) => r.data)
              .toList();
    }
    snapshot['import_archives'] =
        (await _db.customSelect('SELECT * FROM import_archives').get())
            .map((r) => r.data)
            .toList();
    snapshot['invoice_items'] =
        (await _db
                .customSelect(
                  'SELECT item.* FROM invoice_items item JOIN invoices i ON item.invoice_id = i.id WHERE i.workspace_id = ?',
                  variables: [Variable.withString(_wsId)],
                )
                .get())
            .map((r) => r.data)
            .toList();
    return snapshot;
  });

  /// An import never merges into or replaces an existing ledger. Archive and
  /// imported rows commit together, preserving the original file for recovery.
  Future<bool> importBackup(BackupImportPlan plan) async {
    plan.validate();
    final imported = await _db.transaction(() async {
      await _db.customStatement(
        'CREATE TABLE IF NOT EXISTS import_archives (id TEXT PRIMARY KEY, source_json TEXT NOT NULL, imported_at INTEGER NOT NULL)',
      );
      final previous = await _db
          .customSelect(
            'SELECT id FROM import_archives WHERE id=?',
            variables: [Variable.withString(plan.identity)],
          )
          .get();
      if (previous.isNotEmpty) return false;
      for (final table in BackupImportPlan.columns.keys) {
        final rows = await _db
            .customSelect('SELECT 1 FROM $table LIMIT 1')
            .get();
        if (rows.isNotEmpty) {
          throw StateError(
            'الدفتر يحتوي بيانات. لم يتم استبدالها؛ استخدم جهازًا أو دفترًا فارغًا للاستيراد.',
          );
        }
      }
      for (final table in BackupImportPlan.columns.keys) {
        for (final row in plan.tables[table]!) {
          final names = row.keys.toList();
          await _db.customStatement(
            'INSERT INTO $table (${names.join(',')}) VALUES (${List.filled(names.length, '?').join(',')})',
            names.map((n) => row[n]).toList(),
          );
        }
      }
      await _db.customStatement(
        'INSERT INTO import_archives(id,source_json,imported_at) VALUES(?,?,?)',
        [
          plan.identity,
          jsonEncode(plan.source),
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      // The import is a local recovery operation. Do not reuse old outbox
      // operations, cursors or ownership claims against a different backend.
      return true;
    });
    if (imported) LocalQueryChanges.notify();
    return imported;
  }

  Future<void> createTables() async {
    await _db.customStatement(
      'CREATE TABLE IF NOT EXISTS import_archives (id TEXT PRIMARY KEY, source_json TEXT NOT NULL, imported_at INTEGER NOT NULL)',
    );
    await createCatalogTables();
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS invoice_terms (
        invoice_id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        method TEXT NOT NULL CHECK(method IN ('cash','credit','installments')),
        upfront_minor INTEGER NOT NULL CHECK(upfront_minor >= 0),
        months INTEGER NOT NULL CHECK(months BETWEEN 1 AND 120),
        first_due_date INTEGER NOT NULL
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency_code TEXT NOT NULL DEFAULT 'EGP',
        owner_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS customers_ws_idx ON customers(workspace_id)
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        invoice_number TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        total_minor INTEGER NOT NULL DEFAULT 0,
        discount_minor INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        is_manual_amount INTEGER NOT NULL DEFAULT 0,
        invoice_date INTEGER NOT NULL,
        due_date INTEGER,
        version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS invoices_customer_idx ON invoices(customer_id)
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price_minor INTEGER NOT NULL DEFAULT 0,
        discount_minor INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS items_invoice_idx ON invoice_items(invoice_id)
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        notes TEXT,
        payment_date INTEGER NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS payments_customer_idx ON payments(customer_id)
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS ledger_entries (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        notes TEXT,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await _db.customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS ledger_source_idx
        ON ledger_entries(workspace_id, source_id, event_type)
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS ledger_customer_idx ON ledger_entries(customer_id)
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        operation_id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        base_version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_state (
        workspace_id TEXT PRIMARY KEY,
        last_cursor TEXT,
        last_success_at INTEGER,
        pending_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Customer CRUD
  // ──────────────────────────────────────────────────────────────────────────

  Stream<List<CustomerRow>> watchCustomers({String? search}) {
    final q = search != null && search.isNotEmpty
        ? "WHERE workspace_id = ? AND deleted_at IS NULL AND (LOWER(name) LIKE ? OR phone LIKE ?) ORDER BY name"
        : "WHERE workspace_id = ? AND deleted_at IS NULL ORDER BY name";
    final vars = search != null && search.isNotEmpty
        ? [
            Variable.withString(_wsId),
            Variable.withString('%${search.toLowerCase()}%'),
            Variable.withString('%$search%'),
          ]
        : [Variable.withString(_wsId)];
    return _db
        .customSelect('SELECT * FROM customers $q', variables: vars)
        .watchLocal()
        .map((rows) => rows.map(_mapCustomer).toList());
  }

  Stream<CustomerRow?> watchCustomer(String id) {
    return _db
        .customSelect(
          'SELECT * FROM customers WHERE id = ? AND deleted_at IS NULL LIMIT 1',
          variables: [Variable.withString(id)],
        )
        .watchLocal()
        .map((rows) => rows.isEmpty ? null : _mapCustomer(rows.first));
  }

  Future<String> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''INSERT INTO customers
           (id, workspace_id, name, phone, notes, version, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 0, ?, ?)''',
      variables: [
        Variable.withString(id),
        Variable.withString(_wsId),
        Variable.withString(name),
        phone != null ? Variable.withString(phone) : const Variable(null),
        notes != null ? Variable.withString(notes) : const Variable(null),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await _enqueueOutbox(
      entityType: 'customer',
      entityId: id,
      operationType: 'create',
      payload: {
        'id': id,
        'workspace_id': _wsId,
        'name': name,
        'phone': phone,
        'notes': notes,
      },
    );
    LocalQueryChanges.notify();
    return id;
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customUpdate(
      '''UPDATE customers
         SET name=?, phone=?, notes=?, updated_at=?, version=version+1
         WHERE id=?''',
      variables: [
        Variable.withString(name),
        phone != null ? Variable.withString(phone) : const Variable(null),
        notes != null ? Variable.withString(notes) : const Variable(null),
        Variable.withInt(now),
        Variable.withString(id),
      ],
      updateKind: UpdateKind.update,
    );
    await _enqueueOutbox(
      entityType: 'customer',
      entityId: id,
      operationType: 'update',
      payload: {'id': id, 'name': name, 'phone': phone, 'notes': notes},
    );
  }

  Future<void> softDeleteCustomer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customUpdate(
      'UPDATE customers SET deleted_at=?, updated_at=? WHERE id=?',
      variables: [
        Variable.withInt(now),
        Variable.withInt(now),
        Variable.withString(id),
      ],
      updateKind: UpdateKind.update,
    );
    await _enqueueOutbox(
      entityType: 'customer',
      entityId: id,
      operationType: 'delete',
      payload: {'id': id},
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Invoices
  // ──────────────────────────────────────────────────────────────────────────

  Stream<List<InvoiceRow>> watchInvoices(String customerId) {
    return _db
        .customSelect(
          '''SELECT * FROM invoices
             WHERE customer_id = ? AND deleted_at IS NULL
             ORDER BY invoice_date DESC''',
          variables: [Variable.withString(customerId)],
        )
        .watchLocal()
        .map((rows) => rows.map(_mapInvoice).toList());
  }

  Stream<List<InvoiceRow>> watchAllInvoices({String? search, String? status}) {
    final searchClause = search != null && search.isNotEmpty
        ? "AND (LOWER(c.name) LIKE ? OR LOWER(i.notes) LIKE ? OR i.invoice_number LIKE ?)"
        : "";
    final statusClause = status != null && status.isNotEmpty
        ? "AND i.status = ?"
        : "";

    final vars = <Variable>[Variable.withString(_wsId)];
    if (search != null && search.isNotEmpty) {
      vars.add(Variable.withString('%${search.toLowerCase()}%'));
      vars.add(Variable.withString('%${search.toLowerCase()}%'));
      vars.add(Variable.withString('%$search%'));
    }
    if (status != null && status.isNotEmpty) {
      vars.add(Variable.withString(status));
    }

    return _db
        .customSelect('''SELECT i.*, c.name AS customer_name
             FROM invoices i
             LEFT JOIN customers c ON c.id = i.customer_id
             WHERE i.workspace_id = ? AND i.deleted_at IS NULL $searchClause $statusClause
             ORDER BY i.invoice_date DESC''', variables: vars)
        .watchLocal()
        .map((rows) => rows.map(_mapInvoice).toList());
  }

  Stream<InvoiceRow?> watchInvoice(String id) {
    return _db
        .customSelect(
          'SELECT * FROM invoices WHERE id = ? LIMIT 1',
          variables: [Variable.withString(id)],
        )
        .watchLocal()
        .map((rows) => rows.isEmpty ? null : _mapInvoice(rows.first));
  }

  Future<List<InvoiceItemRow>> getInvoiceItems(String invoiceId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY created_at',
          variables: [Variable.withString(invoiceId)],
        )
        .get();
    return rows.map(_mapInvoiceItem).toList();
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceTerms() => _db
      .customSelect(
        'SELECT * FROM invoice_terms WHERE workspace_id = ?',
        variables: [Variable.withString(_wsId)],
      )
      .watchLocal()
      .map((rows) => rows.map((r) => r.data).toList());

  Future<String> createInvoiceWithTerms({
    required String customerId,
    required int totalMinor,
    required int discountMinor,
    required bool isManualAmount,
    required List<Map<String, dynamic>> items,
    required String method,
    required int upfrontMinor,
    required int months,
    required DateTime firstDueDate,
    required DateTime invoiceDate,
    String? notes,
  }) async {
    final net = totalMinor - discountMinor;
    if (totalMinor <= 0 ||
        discountMinor < 0 ||
        net <= 0 ||
        upfrontMinor < 0 ||
        upfrontMinor > net ||
        months < 1 ||
        months > 120 ||
        !['cash', 'credit', 'installments'].contains(method)) {
      throw ArgumentError('Invalid invoice terms');
    }
    if (method == 'cash' && upfrontMinor != net ||
        method == 'installments' &&
            (upfrontMinor == net ||
                firstDueDate.isBefore(
                  DateTime(
                    invoiceDate.year,
                    invoiceDate.month,
                    invoiceDate.day,
                  ),
                ))) {
      throw ArgumentError('Invalid payment schedule');
    }
    return _db
        .transaction(() async {
          final id = await createInvoice(
            customerId: customerId,
            totalMinor: totalMinor,
            discountMinor: discountMinor,
            isManualAmount: isManualAmount,
            items: items,
            notes: notes,
            invoiceDate: invoiceDate,
            dueDate: firstDueDate,
          );
          await _db.customInsert(
            'INSERT INTO invoice_terms (invoice_id, workspace_id, customer_id, method, upfront_minor, months, first_due_date) VALUES (?, ?, ?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(id),
              Variable.withString(_wsId),
              Variable.withString(customerId),
              Variable.withString(method),
              Variable.withInt(upfrontMinor),
              Variable.withInt(months),
              Variable.withInt(firstDueDate.millisecondsSinceEpoch),
            ],
          );
          await _enqueueOutbox(
            entityType: 'invoice',
            entityId: id,
            operationType: 'create',
            payload: {
              'id': id,
              'workspace_id': _wsId,
              'customer_id': customerId,
              'total_minor': totalMinor,
              'discount_minor': discountMinor,
              'invoice_date': invoiceDate.toIso8601String(),
              'notes': notes,
              'items': items,
              'payment_terms': {
                'method': method,
                'upfront_minor': upfrontMinor,
                'months': months,
                'first_due_date': firstDueDate.toIso8601String(),
              },
            },
          );
          await postInvoice(id);
          if (upfrontMinor > 0) {
            await addPayment(
              customerId: customerId,
              amountMinor: upfrontMinor,
              idempotencyKey: 'invoice-upfront:$id',
              notes: 'دفعة مقدمة للفاتورة $id',
              paymentDate: invoiceDate,
            );
          }
          return id;
        })
        .then((id) {
          LocalQueryChanges.notify();
          return id;
        });
  }

  Stream<List<LedgerEntryRow>> watchCustomerLedger(String customerId) => _db
      .customSelect(
        'SELECT l.*, i.invoice_number AS display_reference FROM ledger_entries l LEFT JOIN invoices i ON i.id=l.source_id AND i.workspace_id=l.workspace_id WHERE l.workspace_id = ? AND l.customer_id = ? ORDER BY l.occurred_at, l.id',
        variables: [
          Variable.withString(_wsId),
          Variable.withString(customerId),
        ],
      )
      .watchLocal()
      .map(
        (rows) => rows
            .map(
              (r) => LedgerEntryRow(
                reference: r.readNullable<String>('display_reference'),
                id: r.read<String>('id'),
                workspaceId: r.read<String>('workspace_id'),
                customerId: r.read<String>('customer_id'),
                sourceId: r.read<String>('source_id'),
                eventType: r.read<String>('event_type'),
                amountMinor: r.read<int>('amount_minor'),
                notes: r.readNullable<String>('notes'),
                occurredAt: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('occurred_at'),
                ),
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('created_at'),
                ),
              ),
            )
            .toList(),
      );

  /// Creates a draft invoice (no ledger entry yet).
  /// Call [postInvoice] to post and create the ledger charge.
  Future<String> createInvoice({
    required String customerId,
    required int totalMinor,
    required bool isManualAmount,
    List<Map<String, dynamic>> items = const [],
    int discountMinor = 0,
    String? notes,
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final date = (invoiceDate ?? DateTime.now()).millisecondsSinceEpoch;
    await _db.customInsert(
      '''INSERT INTO invoices
           (id, workspace_id, customer_id, status, total_minor, discount_minor,
            notes, is_manual_amount, invoice_date, due_date,
            version, created_at, updated_at)
         VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, 0, ?, ?)''',
      variables: [
        Variable.withString(id),
        Variable.withString(_wsId),
        Variable.withString(customerId),
        Variable.withInt(totalMinor),
        Variable.withInt(discountMinor),
        notes != null ? Variable.withString(notes) : const Variable(null),
        Variable.withBool(isManualAmount),
        Variable.withInt(date),
        dueDate != null
            ? Variable.withInt(dueDate.millisecondsSinceEpoch)
            : const Variable(null),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    // Insert line items
    for (final item in items) {
      final itemId = _uuid.v4();
      await _db.customInsert(
        '''INSERT INTO invoice_items
             (id, invoice_id, product_id, description, quantity,
              unit_price_minor, discount_minor, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable.withString(itemId),
          Variable.withString(id),
          item['product_id'] != null
              ? Variable.withString(item['product_id'] as String)
              : const Variable(null),
          Variable.withString(item['description'] as String),
          Variable.withInt((item['quantity'] as int?) ?? 1),
          Variable.withInt(item['unit_price_minor'] as int),
          Variable.withInt((item['discount_minor'] as int?) ?? 0),
          Variable.withInt(now),
        ],
      );
    }
    return id;
  }

  /// Posts a draft invoice: sets status='posted', writes ledger debit, enqueues outbox.
  Future<void> postInvoice(String invoiceId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM invoices WHERE id = ? AND deleted_at IS NULL LIMIT 1',
          variables: [Variable.withString(invoiceId)],
        )
        .get();
    if (rows.isEmpty) throw StateError('Invoice $invoiceId not found');
    final inv = _mapInvoice(rows.first);
    if (inv.status != 'draft') {
      throw StateError('Invoice already posted or voided');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final netMinor = inv.netMinor;
    final ledgerId = _uuid.v4();

    // Atomic: update invoice + insert ledger + insert outbox
    await _db.transaction(() async {
      await _db.customUpdate(
        '''UPDATE invoices SET status='posted', updated_at=?, version=version+1
           WHERE id=?''',
        variables: [Variable.withInt(now), Variable.withString(invoiceId)],
        updateKind: UpdateKind.update,
      );
      await _db.customInsert(
        '''INSERT INTO ledger_entries
             (id, workspace_id, customer_id, source_id, event_type,
              amount_minor, notes, occurred_at, created_at)
           VALUES (?, ?, ?, ?, 'invoice_charge', ?, ?, ?, ?)''',
        variables: [
          Variable.withString(ledgerId),
          Variable.withString(inv.workspaceId),
          Variable.withString(inv.customerId),
          Variable.withString(invoiceId),
          Variable.withInt(netMinor),
          inv.notes != null
              ? Variable.withString(inv.notes!)
              : const Variable(null),
          Variable.withInt(inv.invoiceDate.millisecondsSinceEpoch),
          Variable.withInt(now),
        ],
      );
      await _enqueueOutbox(
        entityType: 'invoice',
        entityId: invoiceId,
        operationType: 'update',
        payload: {'id': invoiceId, 'status': 'posted'},
      );
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Payments (customer-level)
  // ──────────────────────────────────────────────────────────────────────────

  Stream<List<PaymentRow>> watchPayments(String customerId) {
    return _db
        .customSelect(
          '''SELECT * FROM payments
             WHERE customer_id = ? AND deleted_at IS NULL
             ORDER BY payment_date DESC''',
          variables: [Variable.withString(customerId)],
        )
        .watchLocal()
        .map((rows) => rows.map(_mapPayment).toList());
  }

  Stream<List<PaymentRow>> watchAllPayments({String? search}) {
    final searchClause = search != null && search.isNotEmpty
        ? "AND (LOWER(c.name) LIKE ? OR LOWER(p.notes) LIKE ?)"
        : "";
    final vars = <Variable>[Variable.withString(_wsId)];
    if (search != null && search.isNotEmpty) {
      vars.add(Variable.withString('%${search.toLowerCase()}%'));
      vars.add(Variable.withString('%${search.toLowerCase()}%'));
    }

    return _db
        .customSelect('''SELECT p.*, c.name AS customer_name
             FROM payments p
             LEFT JOIN customers c ON c.id = p.customer_id
             WHERE p.workspace_id = ? AND p.deleted_at IS NULL $searchClause
             ORDER BY p.payment_date DESC''', variables: vars)
        .watchLocal()
        .map((rows) => rows.map(_mapPayment).toList());
  }

  Stream<WorkspaceStats> watchWorkspaceStats() {
    return _db
        .customSelect(
          '''SELECT
               (SELECT COUNT(*) FROM customers WHERE workspace_id = ? AND deleted_at IS NULL) AS customers_count,
               (SELECT COUNT(*) FROM invoices WHERE workspace_id = ? AND deleted_at IS NULL) AS invoices_count,
               (SELECT COUNT(*) FROM payments WHERE workspace_id = ? AND deleted_at IS NULL) AS payments_count,
               (SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries WHERE workspace_id = ? AND event_type = 'invoice_charge') AS invoiced_minor,
               (SELECT COALESCE(SUM(ABS(amount_minor)), 0) FROM ledger_entries WHERE workspace_id = ? AND event_type = 'payment_receipt') AS collected_minor''',
          variables: [
            Variable.withString(_wsId),
            Variable.withString(_wsId),
            Variable.withString(_wsId),
            Variable.withString(_wsId),
            Variable.withString(_wsId),
          ],
        )
        .watchLocal()
        .map((rows) {
          if (rows.isEmpty) {
            return const WorkspaceStats(
              customersCount: 0,
              invoicesCount: 0,
              paymentsCount: 0,
              totalInvoicedMinor: 0,
              totalCollectedMinor: 0,
            );
          }
          final r = rows.first;
          return WorkspaceStats(
            customersCount: r.read<int>('customers_count'),
            invoicesCount: r.read<int>('invoices_count'),
            paymentsCount: r.read<int>('payments_count'),
            totalInvoicedMinor: r.read<int>('invoiced_minor'),
            totalCollectedMinor: r.read<int>('collected_minor'),
          );
        });
  }

  Stream<List<RecentActivityItem>> watchRecentActivities({int limit = 10}) {
    return _db
        .customSelect(
          '''SELECT
               id, customer_id, customer_name, 'invoice' AS type,
               (total_minor - discount_minor) AS amount_minor,
               invoice_date AS trans_date, notes
             FROM (
               SELECT i.*, c.name AS customer_name
               FROM invoices i
               LEFT JOIN customers c ON c.id = i.customer_id
               WHERE i.workspace_id = ? AND i.deleted_at IS NULL
             )
             UNION ALL
             SELECT
               id, customer_id, customer_name, 'payment' AS type,
               amount_minor, payment_date AS trans_date, notes
             FROM (
               SELECT p.*, c.name AS customer_name
               FROM payments p
               LEFT JOIN customers c ON c.id = p.customer_id
               WHERE p.workspace_id = ? AND p.deleted_at IS NULL
             )
             ORDER BY trans_date DESC
             LIMIT ?''',
          variables: [
            Variable.withString(_wsId),
            Variable.withString(_wsId),
            Variable.withInt(limit),
          ],
        )
        .watchLocal()
        .map(
          (rows) => rows
              .map(
                (r) => RecentActivityItem(
                  id: r.read<String>('id'),
                  customerId: r.read<String>('customer_id'),
                  customerName:
                      r.readNullable<String>('customer_name') ?? 'عميل',
                  type: r.read<String>('type'),
                  amountMinor: r.read<int>('amount_minor'),
                  date: DateTime.fromMillisecondsSinceEpoch(
                    r.read<int>('trans_date'),
                  ),
                  notes: r.readNullable<String>('notes'),
                ),
              )
              .toList(),
        );
  }

  /// Idempotent: if idempotency_key already exists, silently skips.
  Future<void> addPayment({
    required String customerId,
    required int amountMinor,
    required String idempotencyKey,
    String? notes,
    DateTime? paymentDate,
  }) async {
    // Check idempotency
    final existing = await _db
        .customSelect(
          'SELECT id FROM payments WHERE idempotency_key = ? LIMIT 1',
          variables: [Variable.withString(idempotencyKey)],
        )
        .get();
    if (existing.isNotEmpty) return; // Already applied

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final date = (paymentDate ?? DateTime.now()).millisecondsSinceEpoch;
    final ledgerId = _uuid.v4();

    await _db.transaction(() async {
      await _db.customInsert(
        '''INSERT INTO payments
             (id, workspace_id, customer_id, amount_minor, notes,
              payment_date, idempotency_key, version, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)''',
        variables: [
          Variable.withString(id),
          Variable.withString(_wsId),
          Variable.withString(customerId),
          Variable.withInt(amountMinor),
          notes != null ? Variable.withString(notes) : const Variable(null),
          Variable.withInt(date),
          Variable.withString(idempotencyKey),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );
      await _db.customInsert(
        '''INSERT INTO ledger_entries
             (id, workspace_id, customer_id, source_id, event_type,
              amount_minor, notes, occurred_at, created_at)
           VALUES (?, ?, ?, ?, 'payment_receipt', ?, ?, ?, ?)''',
        variables: [
          Variable.withString(ledgerId),
          Variable.withString(_wsId),
          Variable.withString(customerId),
          Variable.withString(id),
          Variable.withInt(-amountMinor), // negative = credit
          notes != null ? Variable.withString(notes) : const Variable(null),
          Variable.withInt(date),
          Variable.withInt(now),
        ],
      );
      await _enqueueOutbox(
        entityType: 'payment',
        entityId: id,
        operationType: 'create',
        payload: {
          'id': id,
          'workspace_id': _wsId,
          'customer_id': customerId,
          'amount_minor': amountMinor,
          'idempotency_key': idempotencyKey,
          'notes': notes,
        },
      );
    });
    LocalQueryChanges.notify();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Balance (derived from ledger — never from mutable aggregates)
  // ──────────────────────────────────────────────────────────────────────────

  Stream<CustomerBalance> watchBalance(String customerId) {
    return _db
        .customSelect(
          '''SELECT
               customer_id,
               COALESCE(SUM(CASE WHEN event_type='invoice_charge' THEN amount_minor ELSE 0 END),0) AS invoiced,
               COALESCE(SUM(CASE WHEN event_type='discount' THEN ABS(amount_minor) ELSE 0 END),0) AS discounts,
               COALESCE(SUM(CASE WHEN event_type='payment_receipt' THEN ABS(amount_minor) ELSE 0 END),0) AS payments,
               COALESCE(SUM(CASE WHEN event_type IN ('refund','adjustment','reversal')
                              THEN amount_minor ELSE 0 END),0) AS adjustments
             FROM ledger_entries
             WHERE customer_id = ?
             GROUP BY customer_id''',
          variables: [Variable.withString(customerId)],
        )
        .watchLocal()
        .map((rows) {
          if (rows.isEmpty) {
            return CustomerBalance(
              customerId: customerId,
              totalInvoicedMinor: 0,
              totalDiscountsMinor: 0,
              totalPaymentsMinor: 0,
              totalAdjustmentsMinor: 0,
            );
          }
          final r = rows.first;
          return CustomerBalance(
            customerId: customerId,
            totalInvoicedMinor: r.read<int>('invoiced'),
            totalDiscountsMinor: r.read<int>('discounts'),
            totalPaymentsMinor: r.read<int>('payments'),
            totalAdjustmentsMinor: r.read<int>('adjustments'),
          );
        });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Outbox
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _enqueueOutbox({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final payloadJson = _encodePayload(payload);
    await _db.customInsert(
      '''INSERT OR IGNORE INTO sync_outbox
           (operation_id, workspace_id, entity_type, entity_id,
            operation_type, payload_json, base_version, created_at, status)
         VALUES (?, ?, ?, ?, ?, ?, 0, ?, 'pending')''',
      variables: [
        Variable.withString(opId),
        Variable.withString(_wsId),
        Variable.withString(entityType),
        Variable.withString(entityId),
        Variable.withString(operationType),
        Variable.withString(payloadJson),
        Variable.withInt(now),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingOutbox({int limit = 50}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db
        .customSelect(
          '''SELECT * FROM sync_outbox
         WHERE workspace_id = ? AND status = 'pending'
           AND (next_retry_at IS NULL OR next_retry_at <= ?)
         ORDER BY created_at ASC
         LIMIT ?''',
          variables: [
            Variable.withString(_wsId),
            Variable.withInt(now),
            Variable.withInt(limit),
          ],
        )
        .get();

    return rows.map((r) => r.data).toList();
  }

  Future<void> markOutboxSending(List<String> opIds) async {
    if (opIds.isEmpty) return;
    final placeholders = List.filled(opIds.length, '?').join(',');
    await _db.customUpdate(
      'UPDATE sync_outbox SET status = \'sending\' WHERE operation_id IN ($placeholders)',
      variables: opIds.map(Variable.withString).toList(),
      updateKind: UpdateKind.update,
    );
  }

  Future<void> markOutboxAcknowledged(List<String> opIds) async {
    if (opIds.isEmpty) return;
    final placeholders = List.filled(opIds.length, '?').join(',');
    await _db.customUpdate(
      'UPDATE sync_outbox SET status = \'acknowledged\' WHERE operation_id IN ($placeholders)',
      variables: opIds.map(Variable.withString).toList(),
      updateKind: UpdateKind.update,
    );
  }

  Future<void> markOutboxFailed(
    String opId,
    String error, {
    bool isPermanent = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isPermanent) {
      await _db.customUpdate(
        '''UPDATE sync_outbox
           SET status = 'needs_attention', last_error = ?, attempts = attempts + 1
           WHERE operation_id = ?''',
        variables: [Variable.withString(error), Variable.withString(opId)],
        updateKind: UpdateKind.update,
      );
    } else {
      // Exponential backoff with capped delay: min(2^attempts * 5s, 300s)
      final rows = await _db
          .customSelect(
            'SELECT attempts FROM sync_outbox WHERE operation_id = ? LIMIT 1',
            variables: [Variable.withString(opId)],
          )
          .get();
      final currentAttempts = rows.isNotEmpty
          ? (rows.first.read<int>('attempts'))
          : 0;
      final delaySeconds = (1 << currentAttempts).clamp(5, 300);
      final nextRetry = now + (delaySeconds * 1000);

      await _db.customUpdate(
        '''UPDATE sync_outbox
           SET status = 'pending', last_error = ?, attempts = attempts + 1, next_retry_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable.withString(error),
          Variable.withInt(nextRetry),
          Variable.withString(opId),
        ],
        updateKind: UpdateKind.update,
      );
    }
  }

  Stream<int> watchPendingOutboxCount() {
    return _db
        .customSelect(
          '''SELECT COUNT(*) AS cnt FROM sync_outbox
             WHERE workspace_id = ? AND status IN ('pending', 'sending')''',
          variables: [Variable.withString(_wsId)],
        )
        .watchLocal()
        .map((rows) => rows.isEmpty ? 0 : rows.first.read<int>('cnt'));
  }

  Future<Map<String, dynamic>?> getSyncState() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM sync_state WHERE workspace_id = ? LIMIT 1',
          variables: [Variable.withString(_wsId)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  Future<void> updateSyncState({
    String? lastCursor,
    int? lastSuccessAt,
    String? lastError,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      '''INSERT INTO sync_state (workspace_id, last_cursor, last_success_at, last_error, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(workspace_id) DO UPDATE SET
           last_cursor = COALESCE(excluded.last_cursor, sync_state.last_cursor),
           last_success_at = COALESCE(excluded.last_success_at, sync_state.last_success_at),
           last_error = excluded.last_error,
           updated_at = excluded.updated_at''',
      [_wsId, lastCursor, lastSuccessAt, lastError, now],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mappers
  // ──────────────────────────────────────────────────────────────────────────

  CustomerRow _mapCustomer(QueryRow r) => CustomerRow(
    id: r.read<String>('id'),
    workspaceId: r.read<String>('workspace_id'),
    name: r.read<String>('name'),
    phone: r.readNullable<String>('phone'),
    notes: r.readNullable<String>('notes'),
    version: r.read<int>('version'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
    deletedAt: r.readNullable<int>('deleted_at') != null
        ? DateTime.fromMillisecondsSinceEpoch(r.read<int>('deleted_at'))
        : null,
  );

  InvoiceRow _mapInvoice(QueryRow r) => InvoiceRow(
    id: r.read<String>('id'),
    workspaceId: r.read<String>('workspace_id'),
    customerId: r.read<String>('customer_id'),
    customerName: r.data.containsKey('customer_name')
        ? r.readNullable<String>('customer_name')
        : null,
    invoiceNumber: r.readNullable<String>('invoice_number'),
    status: r.read<String>('status'),
    totalMinor: r.read<int>('total_minor'),
    discountMinor: r.read<int>('discount_minor'),
    notes: r.readNullable<String>('notes'),
    isManualAmount: r.read<bool>('is_manual_amount'),
    invoiceDate: DateTime.fromMillisecondsSinceEpoch(
      r.read<int>('invoice_date'),
    ),
    dueDate: r.readNullable<int>('due_date') != null
        ? DateTime.fromMillisecondsSinceEpoch(r.read<int>('due_date'))
        : null,
    version: r.read<int>('version'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
    deletedAt: r.readNullable<int>('deleted_at') != null
        ? DateTime.fromMillisecondsSinceEpoch(r.read<int>('deleted_at'))
        : null,
  );

  InvoiceItemRow _mapInvoiceItem(QueryRow r) => InvoiceItemRow(
    id: r.read<String>('id'),
    invoiceId: r.read<String>('invoice_id'),
    productId: r.readNullable<String>('product_id'),
    description: r.read<String>('description'),
    quantity: r.read<int>('quantity'),
    unitPriceMinor: r.read<int>('unit_price_minor'),
    discountMinor: r.read<int>('discount_minor'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
  );

  PaymentRow _mapPayment(QueryRow r) => PaymentRow(
    id: r.read<String>('id'),
    workspaceId: r.read<String>('workspace_id'),
    customerId: r.read<String>('customer_id'),
    customerName: r.data.containsKey('customer_name')
        ? r.readNullable<String>('customer_name')
        : null,
    amountMinor: r.read<int>('amount_minor'),
    notes: r.readNullable<String>('notes'),
    paymentDate: DateTime.fromMillisecondsSinceEpoch(
      r.read<int>('payment_date'),
    ),
    idempotencyKey: r.read<String>('idempotency_key'),
    version: r.read<int>('version'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
    deletedAt: r.readNullable<int>('deleted_at') != null
        ? DateTime.fromMillisecondsSinceEpoch(r.read<int>('deleted_at'))
        : null,
  );

  String _encodePayload(Map<String, dynamic> payload) => jsonEncode(payload);
}

// ─── DatabaseService ─────────────────────────────────────────────────────────

/// Raw SQL tables are not generated Drift entities, so custom queries need an
/// explicit invalidation signal. Queries subscribe before their initial read.
abstract class LocalQueryChanges {
  static final _changes = StreamController<void>.broadcast();
  static void notify() => _changes.add(null);
}

extension LocalQueryStream on Selectable<QueryRow> {
  Stream<List<QueryRow>> watchLocal() => Stream<void>.multi((controller) {
    final sub = LocalQueryChanges._changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.add(null);
    controller.onCancel = sub.cancel;
  }).asyncMap((_) => get());
}
