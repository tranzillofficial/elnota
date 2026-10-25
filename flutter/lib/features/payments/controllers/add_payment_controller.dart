import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../repositories/payment_repository.dart';

class AddPaymentController extends GetxController {
  AddPaymentController({PaymentRepository? repo})
    : _repo = repo ?? PaymentRepository();

  final PaymentRepository _repo;

  // Single idempotency key generated on creation
  final String idempotencyKey = const Uuid().v4();

  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final Rx<DateTime> paymentDate = DateTime.now().obs;
  final RxBool isSaving = false.obs;

  Future<bool> submit(String customerId) async {
    if (isSaving.value) return false;
    final amountMinor = MoneyUtils.parseToMinor(amountCtrl.text) ?? 0;
    if (amountMinor <= 0) {
      showErrorSnack('validation_amount_required'.tr);
      return false;
    }

    isSaving.value = true;
    try {
      await _repo.addPayment(
        customerId: customerId,
        amountMinor: amountMinor,
        idempotencyKey: idempotencyKey,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        paymentDate: paymentDate.value,
      );
      showSuccessSnack('payment_title'.tr);
      return true;
    } catch (e) {
      showErrorSnack('${'error_generic'.tr}: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    notesCtrl.dispose();
    super.onClose();
  }
}
