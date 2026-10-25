import '../models/invoice_terms.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_impl.dart';
import '../models/invoice_model.dart';

class InvoiceRepository {
  InvoiceRepository();
  AppDao get _dao => DatabaseService.to.dao;

  Stream<List<InvoiceModel>> watchByCustomer(String customerId) => _dao
      .watchInvoices(customerId)
      .map((rows) => rows.map(InvoiceModel.fromRow).toList());

  Stream<List<InvoiceModel>> watchAll({String? search, String? status}) => _dao
      .watchAllInvoices(search: search, status: status)
      .map((rows) => rows.map(InvoiceModel.fromRow).toList());

  Stream<InvoiceModel?> watchOne(String id) => _dao
      .watchInvoice(id)
      .map((r) => r == null ? null : InvoiceModel.fromRow(r));

  Future<List<InvoiceItemModel>> getItems(String invoiceId) async {
    final rows = await _dao.getInvoiceItems(invoiceId);
    return rows.map(InvoiceItemModel.fromRow).toList();
  }

  Stream<List<InvoiceTerms>> watchTerms() => _dao.watchInvoiceTerms().map(
    (rows) => rows.map(InvoiceTerms.fromMap).toList(),
  );
  Future<String> createWithTerms({
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
  }) => _dao.createInvoiceWithTerms(
    customerId: customerId,
    totalMinor: totalMinor,
    discountMinor: discountMinor,
    isManualAmount: isManualAmount,
    items: items,
    method: method,
    upfrontMinor: upfrontMinor,
    months: months,
    firstDueDate: firstDueDate,
    invoiceDate: invoiceDate,
    notes: notes,
  );

  /// Create a draft invoice then immediately post it.
  Future<String> createAndPost({
    required String customerId,
    required int totalMinor,
    required bool isManualAmount,
    List<Map<String, dynamic>> items = const [],
    int discountMinor = 0,
    String? notes,
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    final id = await _dao.createInvoice(
      customerId: customerId,
      totalMinor: totalMinor,
      isManualAmount: isManualAmount,
      items: items,
      discountMinor: discountMinor,
      notes: notes,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
    );
    await _dao.postInvoice(id);
    return id;
  }
}
