import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../models/invoice_terms.dart';
import '../repositories/invoice_repository.dart';

class InvoiceFormController extends GetxController {
  InvoiceFormController(this._repo);
  final InvoiceRepository _repo;
  final isManualAmount = false.obs;
  final isSaving = false.obs;
  final method = 'installments'.obs;
  final months = 6.obs;
  final invoiceDate = DateTime.now().obs;
  late final firstDueDate = installmentDate(invoiceDate.value, 1).obs;
  final amountCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  final upfrontCtrl = TextEditingController(text: '0');
  final notesCtrl = TextEditingController();
  final items = <LineItemDraft>[].obs;
  String? savedInvoiceId;
  int get totalMinor => isManualAmount.value
      ? MoneyUtils.parseToMinor(amountCtrl.text) ?? 0
      : items.fold(0, (sum, i) => sum + i.lineTotal);
  int get discountMinor => MoneyUtils.parseToMinor(discountCtrl.text) ?? 0;
  int get netMinor => totalMinor - discountMinor;
  int get upfrontMinor => method.value == 'cash'
      ? netMinor
      : MoneyUtils.parseToMinor(upfrontCtrl.text) ?? 0;
  int get principal => netMinor - upfrontMinor;
  void addItem(LineItemDraft item) => items.add(item);
  void removeItem(int index) => items.removeAt(index);
  Future<bool> save(String customerId) async {
    if (isSaving.value) return false;
    if (netMinor <= 0 ||
        discountMinor < 0 ||
        totalMinor <= 0 ||
        (!isManualAmount.value &&
            (items.isEmpty ||
                items.any(
                  (i) =>
                      i.description.trim().isEmpty ||
                      i.quantity < 1 ||
                      i.unitPriceMinor <= 0,
                )))) {
      showErrorSnack('راجع بنود الفاتورة والمبلغ والخصم');
      return false;
    }
    if (upfrontMinor < 0 ||
        upfrontMinor > netMinor ||
        method.value == 'installments' &&
            (principal < months.value ||
                firstDueDate.value.isBefore(
                  DateTime(
                    invoiceDate.value.year,
                    invoiceDate.value.month,
                    invoiceDate.value.day,
                  ),
                ))) {
      showErrorSnack('راجع المقدم وعدد الشهور وتاريخ أول قسط');
      return false;
    }
    isSaving.value = true;
    try {
      savedInvoiceId = await _repo.createWithTerms(
        customerId: customerId,
        totalMinor: totalMinor,
        discountMinor: discountMinor,
        isManualAmount: isManualAmount.value,
        items: isManualAmount.value
            ? []
            : items
                  .map(
                    (i) => {
                      'description': i.description,
                      'quantity': i.quantity,
                      'unit_price_minor': i.unitPriceMinor,
                      'discount_minor': i.discountMinor,
                    },
                  )
                  .toList(),
        method: method.value,
        upfrontMinor: upfrontMinor,
        months: method.value == 'installments' ? months.value : 1,
        firstDueDate: firstDueDate.value,
        invoiceDate: invoiceDate.value,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      return true;
    } catch (_) {
      showErrorSnack('تعذر حفظ الفاتورة؛ حاول مجددًا');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [amountCtrl, discountCtrl, upfrontCtrl, notesCtrl]) {
      c.dispose();
    }
    super.onClose();
  }
}

class LineItemDraft {
  LineItemDraft({
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
    this.discountMinor = 0,
    Object? editorKey,
  }) : editorKey = editorKey ?? Object();
  final Object editorKey;
  final String description;
  final int quantity;
  final int unitPriceMinor;
  final int discountMinor;
  int get lineTotal => quantity * unitPriceMinor - discountMinor;
}
