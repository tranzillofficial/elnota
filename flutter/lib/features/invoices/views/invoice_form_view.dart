import '../../../core/widgets/customer_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/services/pdf_service.dart';
import '../controllers/invoice_form_controller.dart';
import '../repositories/invoice_repository.dart';
import '../models/invoice_terms.dart';

class InvoiceFormView extends StatefulWidget {
  const InvoiceFormView({super.key});
  @override
  State<InvoiceFormView> createState() => _InvoiceFormViewState();
}

class _InvoiceFormViewState extends State<InvoiceFormView> {
  late final InvoiceFormController ctrl;
  String? customerId;
  @override
  void initState() {
    super.initState();
    customerId =
        (Get.arguments as Map<String, dynamic>?)?['customer_id'] as String?;
    if (!Get.isRegistered<InvoiceFormController>()) {
      Get.put(InvoiceFormController(InvoiceRepository()));
    }
    ctrl = Get.find<InvoiceFormController>();
    for (final c in [ctrl.amountCtrl, ctrl.discountCtrl, ctrl.upfrontCtrl]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [ctrl.amountCtrl, ctrl.discountCtrl, ctrl.upfrontCtrl]) {
      c.removeListener(_changed);
    }
    super.dispose();
  }

  Future<void> _save(bool print) async {
    if (customerId == null) {
      showErrorSnack('اختر العميل أولاً');
      return;
    }
    if (!await ctrl.save(customerId!)) return;
    final id = ctrl.savedInvoiceId!;
    Get.back(result: true);
    if (print) {
      try {
        final repo = InvoiceRepository();
        final invoice = await repo.watchOne(id).first;
        if (invoice != null) {
          final items = await repo.getItems(id);
          await PdfService.printDocument(
            await PdfService.generateInvoicePdf(invoice: invoice, items: items),
          );
        }
      } catch (_) {
        showErrorSnack(
          'تم الحفظ محليًا، وتعذرت الطباعة. يمكنك إعادة الطباعة من الفاتورة.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AccountDataBuilder(
    builder: (context, data) => Obx(() {
      final installment = ctrl.method.value == 'installments';
      final amounts = ctrl.principal >= 0
          ? installmentAmounts(ctrl.principal, ctrl.months.value)
          : <int>[];
      return AccountingFormFrame(
        title: 'فاتورة جديدة',
        busy: ctrl.isSaving.value,
        footer: MediaQuery.sizeOf(context).width < 600
            ? Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ctrl.isSaving.value
                          ? null
                          : () => _save(false),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        ctrl.isSaving.value ? 'جارٍ الحفظ…' : 'حفظ الفاتورة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ctrl.isSaving.value ? null : () => _save(true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('حفظ وطباعة'),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: ctrl.isSaving.value ? null : () => _save(false),
                    child: Text(
                      ctrl.isSaving.value ? 'جارٍ الحفظ…' : 'حفظ الفاتورة',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: ctrl.isSaving.value ? null : () => _save(true),
                    child: const Text('حفظ وطباعة'),
                  ),
                  OutlinedButton(
                    onPressed: ctrl.isSaving.value ? null : () => Get.back(),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
        child: IgnorePointer(
          ignoring: ctrl.isSaving.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormColumns(
                mobileColumns: true,
                children: [
                  LabeledField(
                    'العميل',
                    child: CustomerSearchField(
                      showLabel: false,
                      value: customerId,
                      customers: data.customers
                          .map(
                            (c) =>
                                (id: c.id, name: c.name, phone: c.phone ?? ''),
                          )
                          .toList(),
                      enabled: !ctrl.isSaving.value,
                      onChanged: (id) => setState(() => customerId = id),
                    ),
                  ),
                  LabeledField(
                    'تاريخ الفاتورة',
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: ctrl.invoiceDate.value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) ctrl.invoiceDate.value = date;
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      iconAlignment: IconAlignment.end,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          designDate(ctrl.invoiceDate.value),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              if (MediaQuery.sizeOf(context).width < 600) ...[
                SegmentedButton<bool>(
                  expandedInsets: EdgeInsets.zero,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text('أصناف'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.description_outlined, size: 18),
                      label: Text('مبلغ فقط'),
                    ),
                  ],
                  selected: {ctrl.isManualAmount.value},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) =>
                      ctrl.isManualAmount.value = v.first,
                ),
                if (!ctrl.isManualAmount.value)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'بنود الفاتورة',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => ctrl.addItem(
                            LineItemDraft(
                              description: '',
                              quantity: 1,
                              unitPriceMinor: 0,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة صنف'),
                        ),
                      ],
                    ),
                  ),
              ] else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    const Text(
                      'بنود الفاتورة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.list_alt_outlined, size: 18),
                          label: Text('بنود الفاتورة'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.edit_outlined, size: 18),
                          label: Text('مبلغ فقط'),
                        ),
                      ],
                      selected: {ctrl.isManualAmount.value},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          ctrl.isManualAmount.value = selection.first,
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ctrl.isManualAmount.value = false;
                        ctrl.addItem(
                          LineItemDraft(
                            description: '',
                            quantity: 1,
                            unitPriceMinor: 0,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة بند'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (ctrl.isManualAmount.value)
                LabeledField(
                  'قيمة الفاتورة',
                  child: TextField(
                    controller: ctrl.amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.calculate_outlined),
                      suffixText: 'ج.م',
                      helperText: 'إجمالي الفاتورة بدون إدخال بنود',
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < ctrl.items.length; i++)
                      _LineEditor(
                        key: ObjectKey(ctrl.items[i].editorKey),
                        item: ctrl.items[i],
                        onChanged: (item) => ctrl.items[i] = item,
                        onDelete: () => ctrl.removeItem(i),
                      ),
                    if (ctrl.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'أضف بندًا أو استخدم المبلغ اليدوي',
                          style: TextStyle(color: designMuted),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              FormColumns(
                mobileColumns: true,
                children: [
                  LabeledField(
                    'خصم (اختياري)',
                    child: TextField(
                      controller: ctrl.discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(suffixText: 'ج.م'),
                    ),
                  ),
                  _Total('إجمالي الفاتورة', ctrl.netMinor),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'طريقة السداد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('نقدي')),
                  ButtonSegment(value: 'credit', label: Text('آجل')),
                  ButtonSegment(value: 'installments', label: Text('أقساط')),
                ],
                selected: {ctrl.method.value},
                showSelectedIcon: false,
                onSelectionChanged: (v) => ctrl.method.value = v.first,
              ),
              if (ctrl.method.value != 'cash') ...[
                const SizedBox(height: 16),
                FormColumns(
                  mobileColumns: true,
                  children: [
                    LabeledField(
                      'الدفعة المقدمة',
                      child: TextField(
                        controller: ctrl.upfrontCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          suffixText: 'ج.م',
                          helperText: 'اختياري، يمكن إدخال صفر',
                        ),
                      ),
                    ),
                    if (installment)
                      LabeledField(
                        'عدد شهور القسط',
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: ctrl.months.value > 1
                                  ? () => ctrl.months.value--
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Text(
                                '${ctrl.months.value} شهور',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              onPressed: ctrl.months.value < 120
                                  ? () => ctrl.months.value++
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (installment) ...[
                  const SizedBox(height: 10),
                  FormColumns(
                    mobileColumns: true,
                    children: [
                      _Total('المتبقي للتقسيط', ctrl.principal),
                      _Total(
                        'قيمة القسط الشهري',
                        amounts.isEmpty ? 0 : amounts.first,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                LabeledField(
                  installment ? 'أول قسط' : 'تاريخ الاستحقاق',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: ctrl.firstDueDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) ctrl.firstDueDate.value = d;
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(designDate(ctrl.firstDueDate.value)),
                  ),
                ),
                if (installment) ...[
                  Text(
                    'آخر قسط: ${designDate(installmentDate(ctrl.firstDueDate.value, ctrl.months.value - 1))}',
                    style: const TextStyle(color: designMuted, fontSize: 12),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'عرض جدول الأقساط (${ctrl.months.value} أقساط)',
                    ),
                    children: [
                      for (var i = 0; i < amounts.length; i++)
                        ListTile(
                          dense: true,
                          title: Text(
                            designDate(
                              installmentDate(ctrl.firstDueDate.value, i),
                            ),
                          ),
                          trailing: Text(designMoney(amounts[i])),
                        ),
                    ],
                  ),
                  const Text(
                    'الدفعات تسدد أقدم استحقاق أولاً؛ فروق القروش تُضاف لآخر قسط.',
                    style: TextStyle(color: designMuted, fontSize: 12),
                  ),
                ],
              ],
              if (ctrl.method.value == 'cash')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'سيُسجّل كامل المبلغ كدفعة على حساب العميل مع الفاتورة.',
                    style: TextStyle(color: designGreen),
                  ),
                ),
              const SizedBox(height: 16),
              LabeledField(
                'ملاحظة (اختياري)',
                child: TextField(
                  controller: ctrl.notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'أضف ملاحظة للفاتورة',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.amount);
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: designGreen.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(
          designMoney(amount),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: designGreen,
          ),
        ),
      ],
    ),
  );
}

class _LineEditor extends StatefulWidget {
  const _LineEditor({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });
  final LineItemDraft item;
  final ValueChanged<LineItemDraft> onChanged;
  final VoidCallback onDelete;
  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final desc = TextEditingController(text: widget.item.description);
  late final qty = TextEditingController(text: '${widget.item.quantity}');
  late final price = TextEditingController(
    text: MoneyUtils.formatMinorNoSymbol(widget.item.unitPriceMinor),
  );
  @override
  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
    super.dispose();
  }

  void changed(String _) => widget.onChanged(
    LineItemDraft(
      editorKey: widget.item.editorKey,
      description: desc.text,
      quantity: int.tryParse(qty.text) ?? 0,
      unitPriceMinor: MoneyUtils.parseToMinor(price.text) ?? 0,
    ),
  );
  void adjustQuantity(int delta) {
    final next = (int.tryParse(qty.text) ?? 1) + delta;
    if (next < 1) return;
    setState(() => qty.text = '$next');
    changed('');
  }

  Widget mobileEditor(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
    decoration: BoxDecoration(
      border: Border.all(color: designBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        TextField(
          controller: desc,
          onChanged: changed,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'اسم الصنف / الوصف',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const Divider(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الكمية',
                    style: TextStyle(color: designMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: designBorder),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: IconButton(
                            tooltip: 'زيادة الكمية',
                            onPressed: () => adjustQuantity(1),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add, size: 17),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: qty,
                            onChanged: changed,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 26,
                          child: IconButton(
                            tooltip: 'تقليل الكمية',
                            onPressed: (int.tryParse(qty.text) ?? 1) > 1
                                ? () => adjustQuantity(-1)
                                : null,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سعر الوحدة',
                    style: TextStyle(color: designMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: price,
                      onChanged: changed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 9,
                        ),
                        suffixText: 'ج.م',
                        suffixStyle: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإجمالي',
                    style: TextStyle(color: designMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: designGreen.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        designMoney(widget.item.lineTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 29,
              child: IconButton(
                tooltip: 'حذف البند',
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width < 600
      ? mobileEditor(context)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: FormColumns(
            mobileColumns: true,
            children: [
              TextField(
                controller: desc,
                onChanged: changed,
                decoration: const InputDecoration(labelText: 'الصنف / الوصف'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      onChanged: changed,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: price,
                      onChanged: changed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر الوحدة',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        );
}
