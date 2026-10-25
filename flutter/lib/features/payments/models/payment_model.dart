import '../../../core/database/database_impl.dart';
import '../../../core/utils/money_utils.dart';

/// Domain model for a customer payment.
class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.amountMinor,
    this.notes,
    required this.paymentDate,
    required this.idempotencyKey,
  });

  final String id;
  final String customerId;
  final String? customerName;
  final int amountMinor;
  final String? notes;
  final DateTime paymentDate;
  final String idempotencyKey;

  String get formattedAmount => MoneyUtils.formatMinor(amountMinor);

  factory PaymentModel.fromRow(PaymentRow r) => PaymentModel(
        id: r.id,
        customerId: r.customerId,
        customerName: r.customerName,
        amountMinor: r.amountMinor,
        notes: r.notes,
        paymentDate: r.paymentDate,
        idempotencyKey: r.idempotencyKey,
      );
}
