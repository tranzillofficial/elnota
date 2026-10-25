import '../../../core/database/database_impl.dart';
import '../../../core/utils/money_utils.dart';

/// Immutable domain model for a customer, derived from [CustomerRow].
class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.phone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CustomerModel.fromRow(CustomerRow r) => CustomerModel(
        id: r.id,
        workspaceId: r.workspaceId,
        name: r.name,
        phone: r.phone,
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
}

/// Immutable summary shown in the customer detail header.
class CustomerBalanceSummary {
  const CustomerBalanceSummary({
    required this.customerId,
    required this.totalInvoicedMinor,
    required this.totalDiscountsMinor,
    required this.totalPaymentsMinor,
    required this.outstandingMinor,
  });

  final String customerId;
  final int totalInvoicedMinor;
  final int totalDiscountsMinor;
  final int totalPaymentsMinor;
  final int outstandingMinor;

  bool get hasCredit => outstandingMinor < 0;
  bool get isZero => outstandingMinor == 0;

  String get formattedOutstanding => MoneyUtils.formatMinor(outstandingMinor.abs());
  String get formattedInvoiced => MoneyUtils.formatMinor(totalInvoicedMinor);
  String get formattedPayments => MoneyUtils.formatMinor(totalPaymentsMinor);
  String get formattedDiscounts => MoneyUtils.formatMinor(totalDiscountsMinor);

  factory CustomerBalanceSummary.fromBalance(CustomerBalance b) =>
      CustomerBalanceSummary(
        customerId: b.customerId,
        totalInvoicedMinor: b.totalInvoicedMinor,
        totalDiscountsMinor: b.totalDiscountsMinor,
        totalPaymentsMinor: b.totalPaymentsMinor,
        outstandingMinor: b.outstandingMinor,
      );

  factory CustomerBalanceSummary.fromRow(CustomerBalance b) =>
      CustomerBalanceSummary.fromBalance(b);
}
