import 'package:drift/drift.dart';

/// Drift table definitions for ElNota Phase 1.
/// All monetary values are stored as INTEGER minor units (e.g. piasters × 100).
/// UUIDs are client-generated and stored as TEXT.
/// Tables follow the schema contract in docs/DATABASE.md.
///
/// NOTE: drift_dev / build_runner are NOT in the lockfile.
/// Generated companions/queries are written manually in database_impl.dart.

// ─── Workspaces ─────────────────────────────────────────────────────────────
class Workspaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  TextColumn get ownerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Customers ───────────────────────────────────────────────────────────────
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Products ─────────────────────────────────────────────────────────────────
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  /// Default unit price in minor units.
  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Invoices ─────────────────────────────────────────────────────────────────
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get customerId => text()();
  TextColumn get invoiceNumber => text().nullable()();
  /// 'draft' | 'posted' | 'paid' | 'partial' | 'overdue' | 'cancelled'
  TextColumn get status => text().withDefault(const Constant('draft'))();
  /// Total charged amount (before discount) in minor units.
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
  /// Discount in minor units.
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  /// True when invoice was entered as a manual single amount (no line items).
  BoolColumn get isManualAmount =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get invoiceDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Invoice items ────────────────────────────────────────────────────────────
class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get description => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  /// Unit price snapshot at time of invoice in minor units.
  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Payments ─────────────────────────────────────────────────────────────────
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get customerId => text()();
  /// Customer-level receipt. Not bound to a specific invoice by default.
  IntColumn get amountMinor => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paymentDate => dateTime()();
  /// Idempotency key prevents duplicate application on server.
  TextColumn get idempotencyKey => text()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Ledger entries ──────────────────────────────────────────────────────────
/// Immutable audit log of all financial events.
/// Balance = sum of credits - sum of debits per customer.
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get customerId => text()();
  /// Source reference: invoice_id, payment_id, adjustment_id etc.
  TextColumn get sourceId => text()();
  /// 'invoice_charge' | 'payment_receipt' | 'discount' | 'refund' | 'adjustment' | 'reversal'
  TextColumn get eventType => text()();
  /// Positive = debit (customer owes more); negative = credit (customer owes less).
  IntColumn get amountMinor => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Installment plans ────────────────────────────────────────────────────────
class InstallmentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get customerId => text()();
  TextColumn get invoiceId => text().nullable()();
  IntColumn get totalMinor => integer()();
  IntColumn get installmentCount => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Installment schedule ─────────────────────────────────────────────────────
class InstallmentSchedule extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  IntColumn get installmentNumber => integer()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get dueDate => dateTime()();
  /// 'pending' | 'paid' | 'overdue' | 'partial'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get paidMinor => integer().withDefault(const Constant(0))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Sync outbox ──────────────────────────────────────────────────────────────
class SyncOutbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  /// 'create' | 'update' | 'delete'
  TextColumn get operationType => text()();
  TextColumn get payloadJson => text()();
  IntColumn get baseVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  /// 'pending' | 'in_flight' | 'acknowledged' | 'conflict' | 'failed'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

// ─── Sync state ───────────────────────────────────────────────────────────────
class SyncState extends Table {
  TextColumn get workspaceId => text()();
  TextColumn get lastCursor => text().nullable()();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {workspaceId};
}
