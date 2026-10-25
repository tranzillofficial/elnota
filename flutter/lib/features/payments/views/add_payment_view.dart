import '../../../core/widgets/customer_search_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/add_payment_controller.dart';
import '../repositories/payment_repository.dart';

class AddPaymentView extends StatefulWidget {
  const AddPaymentView({super.key});
  @override
  State<AddPaymentView> createState() => _AddPaymentViewState();
}

class _AddPaymentViewState extends State<AddPaymentView> {
  late final AddPaymentController ctrl;
  String? customerId;
  @override
  void initState() {
    super.initState();
    customerId =
        (Get.arguments as Map<String, dynamic>?)?['customer_id'] as String?;
    if (!Get.isRegistered<AddPaymentController>()) {
      Get.put(AddPaymentController(repo: PaymentRepository()));
    }
    ctrl = Get.find<AddPaymentController>();
    ctrl.amountCtrl.addListener(_amountChanged);
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ctrl.amountCtrl.removeListener(_amountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountDataBuilder(
    builder: (context, data) {
      final customer = data.customers
          .where((c) => c.id == customerId)
          .firstOrNull;
      final balance = data.balances[customerId];
      final amount = MoneyUtils.parseToMinor(ctrl.amountCtrl.text) ?? 0;
      return Obx(
        () => AccountingFormFrame(
          title: 'تسجيل دفعة',
          width: 520,
          busy: ctrl.isSaving.value,
          footer: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: ctrl.isSaving.value || balance == null
                      ? null
                      : () async {
                          if (customerId == null) {
                            showErrorSnack('اختر العميل أولاً');
                            return;
                          }
                          if (await ctrl.submit(customerId!)) {
                            Get.back(result: true);
                          }
                        },
                  child: Text(
                    ctrl.isSaving.value ? 'جارٍ الحفظ…' : 'حفظ الدفعة',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: ctrl.isSaving.value ? null : () => Get.back(),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (customer == null)
                CustomerSearchField(
                  value: customerId,
                  customers: data.customers
                      .map(
                        (c) => (id: c.id, name: c.name, phone: c.phone ?? ''),
                      )
                      .toList(),
                  enabled: !ctrl.isSaving.value,
                  onChanged: (id) => setState(() => customerId = id),
                )
              else
                DesignPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        DesignAvatar(customer.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const Text(
                                'دفعة على حساب العميل',
                                style: TextStyle(color: designMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _BalanceStrip(
                'المتبقي قبل الدفع',
                balance == null ? '—' : designMoney(balance.outstandingMinor),
              ),
              const SizedBox(height: 20),
              LabeledField(
                'مبلغ الدفعة',
                child: TextField(
                  controller: ctrl.amountCtrl,
                  autofocus: true,
                  enabled: !ctrl.isSaving.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    suffixText: 'ج.م',
                    hintText: '0.00',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                balance == null
                    ? 'جارٍ تحميل الرصيد…'
                    : '${balance.outstandingMinor - amount < 0 ? 'رصيد لصالح العميل بعد الدفع' : 'المتبقي بعد الدفع'}: ${designMoney(balance.outstandingMinor - amount)}',
                style: const TextStyle(color: designGreen),
              ),
              const SizedBox(height: 20),
              FormColumns(
                children: [
                  LabeledField(
                    'تاريخ الدفع',
                    child: OutlinedButton.icon(
                      onPressed: ctrl.isSaving.value
                          ? null
                          : () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: ctrl.paymentDate.value,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) ctrl.paymentDate.value = d;
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(designDate(ctrl.paymentDate.value)),
                    ),
                  ),
                  LabeledField(
                    'طريقة الدفع',
                    child: DropdownButtonFormField<String>(
                      initialValue: 'cash',
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                      ],
                      onChanged: ctrl.isSaving.value ? null : (_) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LabeledField(
                'ملاحظة (اختياري)',
                child: TextField(
                  controller: ctrl.notesCtrl,
                  enabled: !ctrl.isSaving.value,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'أضف ملاحظة للدفعة',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تُخصم الدفعة من إجمالي حساب العميل، وتُحفظ محليًا حتى المزامنة.',
                style: TextStyle(color: designMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: designGreen.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 20,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          value,
          style: const TextStyle(
            color: designGreen,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
