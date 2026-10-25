import '../../../core/database/database_impl.dart';
import '../../../core/utils/money_utils.dart';

/// Invoice domain model.
class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.status,
    required this.totalMinor,
    required this.discountMinor,
    this.notes,
    required this.isManualAmount,
    required this.invoiceDate,
    this.dueDate,
  });

  final String id;
  final String customerId;
  final String? customerName;
  final String status;
  final int totalMinor;
  final int discountMinor;
  final String? notes;
  final bool isManualAmount;
  final DateTime invoiceDate;
  final DateTime? dueDate;

  int get netMinor => totalMinor - discountMinor;

  bool get isDraft => status == 'draft';
  bool get isPosted => status == 'posted';

  String get formattedNet => MoneyUtils.formatMinor(netMinor);
  String get formattedTotal => MoneyUtils.formatMinor(totalMinor);

  factory InvoiceModel.fromRow(InvoiceRow r) => InvoiceModel(
        id: r.id,
        customerId: r.customerId,
        customerName: r.customerName,
        status: r.status,
        totalMinor: r.totalMinor,
        discountMinor: r.discountMinor,
        notes: r.notes,
        isManualAmount: r.isManualAmount,
        invoiceDate: r.invoiceDate,
        dueDate: r.dueDate,
      );
}

/// Line-item model.
class InvoiceItemModel {
  const InvoiceItemModel({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
    required this.discountMinor,
    this.productId,
  });

  final String id;
  final String description;
  final int quantity;
  final int unitPriceMinor;
  final int discountMinor;
  final String? productId;

  int get lineTotal => quantity * unitPriceMinor - discountMinor;

  factory InvoiceItemModel.fromRow(InvoiceItemRow r) => InvoiceItemModel(
        id: r.id,
        description: r.description,
        quantity: r.quantity,
        unitPriceMinor: r.unitPriceMinor,
        discountMinor: r.discountMinor,
        productId: r.productId,
      );
}
