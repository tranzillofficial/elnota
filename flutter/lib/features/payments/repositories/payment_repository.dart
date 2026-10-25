import '../../../core/database/app_database.dart';
import '../../../core/database/database_impl.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  PaymentRepository();
  AppDao get _dao => DatabaseService.to.dao;

  Stream<List<PaymentModel>> watchByCustomer(String customerId) => _dao
      .watchPayments(customerId)
      .map((rows) => rows.map(PaymentModel.fromRow).toList());

  Stream<List<PaymentModel>> watchAll({String? search}) => _dao
      .watchAllPayments(search: search)
      .map((rows) => rows.map(PaymentModel.fromRow).toList());

  Future<void> addPayment({
    required String customerId,
    required int amountMinor,
    required String idempotencyKey,
    String? notes,
    DateTime? paymentDate,
  }) => _dao.addPayment(
    customerId: customerId,
    amountMinor: amountMinor,
    idempotencyKey: idempotencyKey,
    notes: notes,
    paymentDate: paymentDate,
  );
}
