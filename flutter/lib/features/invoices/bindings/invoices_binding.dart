import 'package:get/get.dart';
import '../controllers/invoice_form_controller.dart';
import '../repositories/invoice_repository.dart';

class InvoicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InvoiceRepository>(() => InvoiceRepository());
    Get.lazyPut<InvoiceFormController>(
      () => InvoiceFormController(Get.find<InvoiceRepository>()),
    );
  }
}
