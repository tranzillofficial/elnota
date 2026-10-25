import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/utils/app_routes.dart';

class CustomerDetailView extends StatefulWidget {
  const CustomerDetailView({super.key});
  @override
  State<CustomerDetailView> createState() => _CustomerDetailViewState();
}

class _CustomerDetailViewState extends State<CustomerDetailView> {
  int tab = 0;
  String invoiceFilter = 'all';
  final String customerId =
      (Get.arguments as Map<String, dynamic>?)?['id'] as String? ?? '';
  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: AccountDataBuilder(
        builder: (context, data) {
          final customer = data.customers
              .where((c) => c.id == customerId)
              .firstOrNull;
          if (customer == null) {
            return const Center(child: Text('العميل غير موجود'));
          }
          final balance = data.balances[customerId];
          final invoices =
              data.invoices.where((i) => i.customerId == customerId).toList()
                ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
          final payments =
              data.payments.where((p) => p.customerId == customerId).toList()
                ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
          final movements = [
            for (final i in invoices)
              (
                i.invoiceDate,
                'فاتورة',
                'فاتورة ${i.displayNumber}',
                i.netMinor,
              ),
            for (final p in payments)
              (
                p.paymentDate,
                'دفعة',
                p.notes ?? 'دفعة من العميل',
                p.amountMinor,
              ),
          ]..sort((a, b) => b.$1.compareTo(a.$1));
          final filteredInvoices = invoices
              .where((i) => invoiceFilter == 'all' || i.status == invoiceFilter)
              .toList();
          void statement() => Get.toNamed(
            AppRoutes.customerStatement,
            arguments: {'id': customerId},
          );
          final main = Column(
            children: [
              DesignPanel(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('الفواتير')),
                              ButtonSegment(value: 1, label: Text('الدفعات')),
                              ButtonSegment(
                                value: 2,
                                label: Text('كشف الحساب'),
                              ),
                            ],
                            selected: {tab},
                            showSelectedIcon: false,
                            onSelectionChanged: (v) {
                              if (v.first == 2) {
                                statement();
                              } else {
                                setState(() => tab = v.first);
                              }
                            },
                          ),
                          if (tab == 0)
                            DropdownButton<String>(
                              value: invoiceFilter,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('كل الفواتير'),
                                ),
                                DropdownMenuItem(
                                  value: 'posted',
                                  child: Text('مرحّلة'),
                                ),
                                DropdownMenuItem(
                                  value: 'draft',
                                  child: Text('مسودة'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => invoiceFilter = v!),
                            ),
                        ],
                      ),
                    ),
                    if (tab == 0)
                      DesignTable(
                        headers: const [
                          'رقم الفاتورة',
                          'التاريخ',
                          'الحالة',
                          'القيمة',
                          'الإجراءات',
                        ],
                        rows: filteredInvoices
                            .map(
                              (i) => <Widget>[
                                Text(i.displayNumber),
                                Text(designDate(i.invoiceDate)),
                                DesignPill(
                                  i.isPosted ? 'مرحّلة' : 'مسودة',
                                  color: i.isPosted
                                      ? designGreen
                                      : Colors.orange,
                                ),
                                Text(i.formattedNet),
                                IconButton(
                                  tooltip: 'عرض الفاتورة',
                                  onPressed: () => Get.toNamed(
                                    AppRoutes.invoiceDetail,
                                    arguments: {'id': i.id},
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                              ],
                            )
                            .toList(),
                      ),
                    if (tab == 1)
                      DesignTable(
                        headers: const ['التاريخ', 'الوصف', 'القيمة'],
                        rows: payments
                            .map(
                              (p) => <Widget>[
                                Text(designDate(p.paymentDate)),
                                Text(p.notes ?? 'دفعة من العميل'),
                                Text(
                                  p.formattedAmount,
                                  style: const TextStyle(color: designGreen),
                                ),
                              ],
                            )
                            .toList(),
                      ),
                    if (tab == 2)
                      DesignTable(
                        headers: const ['التاريخ', 'النوع', 'الوصف', 'المبلغ'],
                        rows: movements
                            .map(
                              (m) => <Widget>[
                                Text(designDate(m.$1)),
                                DesignPill(m.$2),
                                Text(m.$3),
                                Text(designMoney(m.$4)),
                              ],
                            )
                            .toList(),
                      ),
                    if ((tab == 0 && filteredInvoices.isEmpty) ||
                        (tab == 1 && payments.isEmpty) ||
                        (tab == 2 && movements.isEmpty))
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('لا توجد حركات مسجلة'),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 10,
                        spacing: 16,
                        children: [
                          Text(
                            '${tab == 1 ? payments.length : invoices.length} ${tab == 1 ? 'دفعات' : 'فواتير'}',
                            style: const TextStyle(color: designMuted),
                          ),
                          Text(
                            'الإجمالي  ${tab == 1 ? balance?.formattedPayments ?? '—' : balance?.formattedInvoiced ?? '—'}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              DesignPanel(
                title: 'آخر الحركات',
                child: DesignTable(
                  headers: const ['التاريخ', 'النوع', 'الوصف', 'المبلغ'],
                  rows: movements
                      .take(4)
                      .map(
                        (m) => <Widget>[
                          Text(designDate(m.$1)),
                          DesignPill(
                            m.$2,
                            color: m.$2 == 'دفعة' ? designGreen : designMuted,
                          ),
                          Text(m.$3),
                          Text(
                            designMoney(m.$4),
                            style: TextStyle(
                              color: m.$2 == 'دفعة' ? designGreen : null,
                            ),
                          ),
                        ],
                      )
                      .toList(),
                ),
              ),
            ],
          );
          final side = Column(
            children: [
              DesignPanel(
                title: 'الأقساط المستحقة',
                child: Column(
                  children: [
                    for (final due
                        in data.dues
                            .where(
                              (d) =>
                                  d.customerId == customerId &&
                                  d.remainingMinor > 0,
                            )
                            .take(5))
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 16,
                          children: [
                            Text(designDate(due.date)),
                            Text(
                              designMoney(due.remainingMinor),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: due.overdueAt(DateTime.now())
                                    ? Colors.red
                                    : null,
                              ),
                            ),
                            DesignPill(
                              due.overdueAt(DateTime.now()) ? 'متأخر' : 'قادم',
                              color: due.overdueAt(DateTime.now())
                                  ? Colors.red
                                  : designGreen,
                            ),
                          ],
                        ),
                      ),
                    if (!data.dues.any(
                      (d) => d.customerId == customerId && d.remainingMinor > 0,
                    ))
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('لا توجد أقساط مستحقة'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              DesignPanel(
                title: 'بيانات العميل',
                action: TextButton(
                  onPressed: () => Get.toNamed(
                    AppRoutes.customerCreate,
                    arguments: {'id': customerId, 'edit': true},
                  ),
                  child: const Text('تعديل البيانات'),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _Info(
                        Icons.phone_outlined,
                        'رقم الهاتف',
                        customer.phone ?? '—',
                      ),
                      _Info(
                        Icons.calendar_month_outlined,
                        'تاريخ إضافة العميل',
                        designDate(customer.createdAt),
                      ),
                      _Info(
                        Icons.notes_outlined,
                        'ملاحظات',
                        customer.notes ?? '—',
                      ),
                      if (balance != null)
                        _Info(
                          Icons.discount_outlined,
                          'الخصومات',
                          balance.formattedDiscounts,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
          return ListView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 30,
            ),
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('العملاء / حساب العميل'),
                  ),
                  const SyncStatusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              DesignHeader(
                title: customer.name,
                subtitle: customer.phone,
                actions: [
                  DesignAction(
                    'تسجيل دفعة',
                    Icons.add,
                    () => customerAction(AppRoutes.paymentCreate, customerId),
                    primary: true,
                  ),
                  DesignAction(
                    'فاتورة جديدة',
                    Icons.description_outlined,
                    () => customerAction(AppRoutes.invoiceCreate, customerId),
                  ),
                  DesignAction('كشف حساب', Icons.print_outlined, statement),
                ],
              ),
              DesignStats(
                children: [
                  DesignStat(
                    'إجمالي الفواتير',
                    balance?.formattedInvoiced ?? '—',
                    Icons.description_outlined,
                  ),
                  DesignStat(
                    'إجمالي المدفوع',
                    balance?.formattedPayments ?? '—',
                    Icons.payment_outlined,
                  ),
                  DesignStat(
                    balance?.hasCredit == true
                        ? 'رصيد دائن للعميل'
                        : 'المتبقي على العميل',
                    balance?.formattedOutstanding ?? '—',
                    Icons.bar_chart,
                    highlight: true,
                  ),
                  DesignStat(
                    'منها متأخر',
                    designMoney(
                      data.dues
                          .where(
                            (d) =>
                                d.customerId == customerId &&
                                d.overdueAt(DateTime.now()),
                          )
                          .fold<int>(0, (sum, d) => sum + d.remainingMinor),
                    ),
                    Icons.access_time,
                    color: Colors.red,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 1050
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: main),
                          const SizedBox(width: 18),
                          Expanded(child: side),
                        ],
                      )
                    : Column(
                        children: [main, const SizedBox(height: 18), side],
                      ),
              ),
            ],
          );
        },
      ),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 600
            ? Row(
                children: [
                  DesignSidebar(
                    selected: 1,
                    onSelect: (i) =>
                        Get.offAllNamed(AppRoutes.home, arguments: {'tab': i}),
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        Icon(icon, color: designMuted, size: 22),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: const TextStyle(color: designMuted)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
