import '../models/account_statement.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_impl.dart';
import '../models/customer_model.dart';

/// Data access layer for customers.
/// All mutations write a sync-outbox entry in the same transaction.
class CustomerRepository {
  CustomerRepository();
  AppDao get _dao => DatabaseService.to.dao;

  Stream<List<CustomerModel>> watchAll({String? search}) => _dao
      .watchCustomers(search: search)
      .map((rows) => rows.map(CustomerModel.fromRow).toList());

  Stream<CustomerModel?> watchOne(String id) => _dao
      .watchCustomer(id)
      .map((r) => r == null ? null : CustomerModel.fromRow(r));

  Stream<CustomerBalanceSummary> watchBalance(String customerId) =>
      _dao.watchBalance(customerId).map(CustomerBalanceSummary.fromBalance);

  Stream<List<StatementMovement>> watchLedger(String customerId) => _dao
      .watchCustomerLedger(customerId)
      .map((rows) => rows.map(StatementMovement.fromLedger).toList());

  Future<String> create({required String name, String? phone, String? notes}) =>
      _dao.createCustomer(name: name, phone: phone, notes: notes);

  Future<void> update({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) => _dao.updateCustomer(id: id, name: name, phone: phone, notes: notes);

  Future<void> delete(String id) => _dao.softDeleteCustomer(id);
}
