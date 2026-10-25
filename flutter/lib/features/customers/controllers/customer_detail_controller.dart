import 'dart:async';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

/// Drives the customer detail screen (balance header + invoice + payment tabs).
class CustomerDetailController extends GetxController {
  CustomerDetailController(this._repo, this.customerId);
  final CustomerRepository _repo;
  final String customerId;

  final Rx<CustomerModel?> customer = Rx<CustomerModel?>(null);
  final Rx<CustomerBalanceSummary?> balance = Rx<CustomerBalanceSummary?>(null);
  final RxBool isLoading = true.obs;

  StreamSubscription<CustomerModel?>? _customerSub;
  StreamSubscription<CustomerBalanceSummary>? _balanceSub;

  @override
  void onInit() {
    super.onInit();
    _customerSub = _repo.watchOne(customerId).listen((c) {
      customer.value = c;
      isLoading.value = false;
    });
    _balanceSub = _repo.watchBalance(customerId).listen((b) {
      balance.value = b;
    });
  }

  @override
  void onClose() {
    _customerSub?.cancel();
    _balanceSub?.cancel();
    super.onClose();
  }
}
