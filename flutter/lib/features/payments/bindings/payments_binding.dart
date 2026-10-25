import 'package:get/get.dart';
import '../controllers/add_payment_controller.dart';
import '../repositories/payment_repository.dart';

class PaymentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentRepository>(() => PaymentRepository());
    Get.lazyPut<AddPaymentController>(
      () => AddPaymentController(repo: Get.find<PaymentRepository>()),
    );
  }
}
