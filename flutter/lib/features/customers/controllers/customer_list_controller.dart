import 'dart:async';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

/// Drives the customers list screen.
/// Reactive search with debounce; soft-delete with confirmation.
class CustomerListController extends GetxController {
  CustomerListController(this._repo);
  final CustomerRepository _repo;

  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = true.obs;

  StreamSubscription<List<CustomerModel>>? _sub;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    _subscribe('');
    debounce(
      searchQuery,
      (q) => _subscribe(q),
      time: const Duration(milliseconds: 300),
    );
  }

  void _subscribe(String q) {
    _sub?.cancel();
    isLoading.value = true;
    _sub = _repo.watchAll(search: q.isEmpty ? null : q).listen(
      (list) {
        customers.assignAll(list);
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  void onSearchChanged(String q) => searchQuery.value = q;

  Future<void> deleteCustomer(String id) async {
    await _repo.delete(id);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
