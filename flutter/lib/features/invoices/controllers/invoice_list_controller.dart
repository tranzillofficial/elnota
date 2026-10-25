import 'dart:async';
import 'package:get/get.dart';
import '../models/invoice_model.dart';
import '../repositories/invoice_repository.dart';

class InvoiceListController extends GetxController {
  InvoiceListController({required this.customerId, InvoiceRepository? repo})
      : _repo = repo ?? InvoiceRepository();

  final String customerId;
  final InvoiceRepository _repo;

  final RxList<InvoiceModel> invoices = <InvoiceModel>[].obs;
  final RxBool isLoading = true.obs;
  StreamSubscription<List<InvoiceModel>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _repo.watchByCustomer(customerId).listen((list) {
      invoices.assignAll(list);
      isLoading.value = false;
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
