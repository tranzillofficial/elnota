import 'package:get/get.dart';
import '../controllers/customer_list_controller.dart';
import '../repositories/customer_repository.dart';

class CustomersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerRepository>(() => CustomerRepository());
    Get.lazyPut<CustomerListController>(
      () => CustomerListController(Get.find()),
    );
  }
}
