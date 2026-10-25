import '../../../core/widgets/mobile_design.dart';
import '../models/invoice_terms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/app_routes.dart';
import '../models/invoice_model.dart';
import '../repositories/invoice_repository.dart';

class AllInvoicesView extends StatefulWidget {
  const AllInvoicesView({super.key});
  @override
  State<AllInvoicesView> createState() => _AllInvoicesViewState();
}

class _AllInvoicesViewState extends State<AllInvoicesView> {
  int tab =
      (Get.arguments is Map && (Get.arguments as Map)['installments'] == true)
      ? 1
      : 0;
  int page = 0;
  String query = '';
  String method = 'all';
  String status = 'all';
  String month = 'all';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AccountDataBuilder(
        builder: (context, data) {
          final terms = {for (final t in data.terms) t.invoiceId: t};
          final names = {for (final c in data.customers) c.id: c.name};
          final months =
              data.invoices
                  .map(
                    (i) =>
                        '${i.invoiceDate.year}/${i.invoiceDate.month.toString().padLeft(2, '0')}',
                  )
                  .toSet()
                  .toList()
                ..sort((a, b) => b.compareTo(a));
          final filtered =
              data.invoices
                  .where(
                    (i) =>
                        ('${names[i.customerId] ?? i.customerName ?? ''} ${i.displayNumber} ${i.id}'
                            .contains(query)) &&
                        (method == 'all' ||
                            (terms[i.id]?.method ?? 'credit') == method) &&
                        (status == 'all' || i.status == status) &&
                        (month == 'all' ||
                            '${i.invoiceDate.year}/${i.invoiceDate.month.toString().padLeft(2, '0')}' ==
                                month),
                  )
                  .toList()
                ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
          final pages = (filtered.length / 8).ceil();
          final current = pages == 0 ? 0 : page.clamp(0, pages - 1);
          final visible = filtered.skip(current * 8).take(8).toList();
          final overdue = data.dues
              .where((d) => d.overdueAt(DateTime.now()))
              .toList();
          final schedule =
              data.dues
                  .where(
                    (d) => ('${names[d.customerId]} ${d.invoiceId}'.contains(
                      query,
                    )),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          if (MediaQuery.sizeOf(context).width < 600) {
            return _mobile(data, filtered, schedule, overdue, months);
          }
          return ListView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            ),
            children: [
              DesignHeader(
                title: 'الفواتير',
                subtitle: 'إدارة فواتير البيع ومتابعة الأقساط',
                actions: [
                  DesignAction(
                    'تصدير',
                    Icons.upload_outlined,
                    () => ExcelExportService.exportAndShareWorkbook(
                      customers: data.customers,
                      invoices: filtered,
                    ),
                  ),
                  DesignAction(
                    'فاتورة جديدة',
                    Icons.add,
                    () => Get.toNamed(AppRoutes.invoiceCreate),
                    primary: true,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 16),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: tab == i ? designGreen : designMuted,
                        ),
                        onPressed: () => setState(() => tab = i),
                        child: Text(
                          i == 0
                              ? 'الفواتير'
                              : 'جدول الأقساط (${overdue.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 14),
              DesignStats(
                children: [
                  DesignStat(
                    'عدد الفواتير',
                    '${data.invoices.length}',
                    Icons.description_outlined,
                  ),
                  DesignStat(
                    'قيمة الفواتير',
                    designMoney(
                      data.invoices
                          .where((i) => i.isPosted)
                          .fold<int>(0, (sum, i) => sum + i.netMinor),
                    ),
                    Icons.storage_outlined,
                  ),
                  DesignStat(
                    'فواتير آجل وأقساط',
                    '${data.invoices.where((i) => terms[i.id]?.method != 'cash').length}',
                    Icons.pie_chart_outline,
                  ),
                  DesignStat(
                    'أقساط متأخرة',
                    designMoney(
                      overdue.fold<int>(0, (sum, d) => sum + d.remainingMinor),
                    ),
                    Icons.access_time,
                    color: Colors.red,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DesignPanel(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width < 500
                                ? 270
                                : 390,
                            child: TextField(
                              onChanged: (v) => setState(() {
                                query = v;
                                page = 0;
                              }),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'ابحث برقم الفاتورة أو اسم العميل',
                              ),
                            ),
                          ),
                          if (tab == 0)
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'all',
                                  label: Text('الكل'),
                                ),
                                ButtonSegment(
                                  value: 'cash',
                                  label: Text('نقدي'),
                                ),
                                ButtonSegment(
                                  value: 'credit',
                                  label: Text('آجل'),
                                ),
                                ButtonSegment(
                                  value: 'installments',
                                  label: Text('أقساط'),
                                ),
                              ],
                              selected: {method},
                              showSelectedIcon: false,
                              onSelectionChanged: (v) => setState(() {
                                method = v.first;
                                page = 0;
                              }),
                            ),
                          DropdownButton<String>(
                            value: months.contains(month) ? month : 'all',
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('كل الشهور'),
                              ),
                              for (final m in months)
                                DropdownMenuItem(value: m, child: Text(m)),
                            ],
                            onChanged: (v) => setState(() {
                              month = v!;
                              page = 0;
                            }),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'تصفية الحالة',
                            onSelected: (v) => setState(() {
                              status = v;
                              page = 0;
                            }),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'all',
                                child: Text('كل الحالات'),
                              ),
                              PopupMenuItem(
                                value: 'posted',
                                child: Text('مرحّلة'),
                              ),
                              PopupMenuItem(
                                value: 'draft',
                                child: Text('مسودة'),
                              ),
                              PopupMenuItem(
                                value: 'voided',
                                child: Text('ملغاة'),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune, size: 20),
                                  SizedBox(width: 8),
                                  Text('تصفية'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tab == 0)
                      DesignTable(
                        minWidth: 1100,
                        rowHeight: 64,
                        headers: const [
                          'الفاتورة',
                          'العميل',
                          'التاريخ',
                          'طريقة السداد',
                          'الإجمالي',
                          'المقدم',
                          'الحالة',
                          'إجراءات',
                        ],
                        rows: visible.map((i) {
                          final t = terms[i.id];
                          final m = t?.method ?? 'credit';
                          return <Widget>[
                            Text(
                              '#${i.displayNumber}',
                              style: const TextStyle(
                                color: designGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: () => openCustomer(i.customerId),
                              child: Text(
                                names[i.customerId] ?? i.customerName ?? '—',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(designDate(i.invoiceDate)),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DesignPill(
                                  m == 'cash'
                                      ? 'نقدي'
                                      : m == 'installments'
                                      ? 'أقساط'
                                      : 'آجل',
                                  color: m == 'installments'
                                      ? Colors.blue
                                      : m == 'credit'
                                      ? Colors.orange
                                      : designGreen,
                                ),
                                if (m == 'installments')
                                  Text(
                                    '${t!.months} شهور',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: designMuted,
                                    ),
                                  ),
                              ],
                            ),
                            Text(i.formattedNet),
                            Text(t == null ? '—' : designMoney(t.upfrontMinor)),
                            DesignPill(
                              i.isPosted
                                  ? 'مرحّلة'
                                  : i.isDraft
                                  ? 'مسودة'
                                  : 'ملغاة',
                              color: i.isPosted ? designGreen : designMuted,
                            ),
                            _InvoiceMenu(
                              invoice: i,
                              name: names[i.customerId],
                              onSchedule: () => setState(() {
                                tab = 1;
                                query = i.id;
                              }),
                            ),
                          ];
                        }).toList(),
                      )
                    else
                      DesignTable(
                        minWidth: 850,
                        headers: const [
                          'العميل',
                          'الفاتورة',
                          'القسط',
                          'تاريخ الاستحقاق',
                          'المبلغ',
                          'المتبقي',
                          'الحالة',
                        ],
                        rows: schedule
                            .map(
                              (d) => <Widget>[
                                InkWell(
                                  onTap: () => openCustomer(d.customerId),
                                  child: Text(names[d.customerId] ?? '—'),
                                ),
                                Text('#${d.invoiceId.substring(0, 8)}'),
                                Text('${d.index}'),
                                Text(designDate(d.date)),
                                Text(designMoney(d.amountMinor)),
                                Text(designMoney(d.remainingMinor)),
                                DesignPill(
                                  d.remainingMinor == 0
                                      ? 'مسدد'
                                      : d.overdueAt(DateTime.now())
                                      ? 'متأخر'
                                      : 'قادم',
                                  color: d.overdueAt(DateTime.now())
                                      ? Colors.red
                                      : designGreen,
                                ),
                              ],
                            )
                            .toList(),
                      ),
                    if (tab == 0 && visible.isEmpty ||
                        tab == 1 && schedule.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('لا توجد بيانات مطابقة'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    tab == 0
                        ? 'عرض ${filtered.isEmpty ? 0 : current * 8 + 1} – ${current * 8 + visible.length} من ${filtered.length} فاتورة'
                        : 'تسدد الدفعات أقدم استحقاق أولاً، والمقدم هو المبلغ المسجل عند إنشاء الفاتورة.',
                    style: const TextStyle(color: designMuted, fontSize: 12),
                  ),
                  if (tab == 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: current > 0
                              ? () => setState(() => page = current - 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        for (var i = 0; i < pages; i++)
                          if ((i - current).abs() < 3)
                            TextButton(
                              onPressed: () => setState(() => page = i),
                              child: Text('${i + 1}'),
                            ),
                        IconButton(
                          onPressed: current + 1 < pages
                              ? () => setState(() => page = current + 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget _mobile(
    AccountData data,
    List<InvoiceModel> filtered,
    List<ScheduledDue> schedule,
    List<ScheduledDue> overdue,
    List<String> months,
  ) {
    final rows = filtered.take((page + 1) * 6).toList();
    final dues = schedule.take((page + 1) * 6).toList();
    final names = {for (final c in data.customers) c.id: c.name};
    final terms = {for (final t in data.terms) t.invoiceId: t};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'الفواتير',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'تصدير الفواتير',
              onPressed: () => ExcelExportService.exportAndShareWorkbook(
                customers: data.customers,
                invoices: filtered,
              ),
              icon: const Icon(Icons.ios_share_outlined, color: designMuted),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    tab = i;
                    page = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == i ? designGreen : designBorder,
                          width: tab == i ? 3 : 1,
                        ),
                      ),
                    ),
                    child: Text(
                      i == 0 ? 'الفواتير' : 'جدول الأقساط (${overdue.length})',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tab == i ? designGreen : designMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MobileStatRow(
          children: [
            MobileStat(
              'عدد الفواتير',
              '${data.invoices.length}',
              Icons.description_outlined,
              color: Colors.blue,
            ),
            MobileStat(
              'قيمة الفواتير',
              designMoney(
                data.invoices
                    .where((i) => i.isPosted)
                    .fold<int>(0, (sum, i) => sum + i.netMinor),
              ),
              Icons.payments_outlined,
            ),
            MobileStat(
              'متأخرات الأقساط',
              designMoney(
                overdue.fold<int>(0, (sum, d) => sum + d.remainingMinor),
              ),
              Icons.alarm_outlined,
              color: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() {
            query = v;
            page = 0;
          }),
          decoration: const InputDecoration(
            hintText: 'ابحث برقم الفاتورة أو العميل',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        if (tab == 0)
          MobileFilters<String>(
            values: const [
              ('all', 'الكل'),
              ('cash', 'نقدي'),
              ('credit', 'آجل'),
              ('installments', 'أقساط'),
            ],
            selected: method,
            onChanged: (v) => setState(() {
              method = v;
              page = 0;
            }),
            trailing: IconButton(
              tooltip: 'اختيار الشهر',
              onPressed: () => _chooseMonth(months),
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: designMuted,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  month == 'all' ? 'كل الشهور' : month,
                  style: const TextStyle(color: designMuted, fontSize: 13),
                ),
              ),
              if (tab == 0)
                PopupMenuButton<String>(
                  tooltip: 'حالة الفاتورة',
                  icon: const Icon(Icons.tune, size: 20, color: designMuted),
                  onSelected: (v) => setState(() {
                    status = v;
                    page = 0;
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('كل الحالات')),
                    PopupMenuItem(value: 'posted', child: Text('مرحّلة')),
                    PopupMenuItem(value: 'draft', child: Text('مسودة')),
                    PopupMenuItem(value: 'voided', child: Text('ملغاة')),
                  ],
                ),
            ],
          ),
        ),
        if (tab == 0)
          for (final i in rows)
            Builder(
              builder: (context) {
                final t = terms[i.id];
                final m = t?.method ?? 'credit';
                return MobileRecordCard(
                  onTap: () => Get.toNamed(
                    AppRoutes.invoiceDetail,
                    arguments: {'invoice_id': i.id},
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    names[i.customerId] ??
                                        i.customerName ??
                                        '—',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '#${i.displayNumber}',
                                  style: const TextStyle(
                                    color: designGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  designDate(i.invoiceDate),
                                  style: const TextStyle(
                                    color: designMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                DesignPill(
                                  m == 'cash'
                                      ? 'نقدي'
                                      : m == 'installments'
                                      ? 'أقساط'
                                      : 'آجل',
                                  color: m == 'installments'
                                      ? Colors.blue
                                      : m == 'cash'
                                      ? designGreen
                                      : Colors.orange,
                                ),
                                if (!i.isPosted)
                                  Text(
                                    i.isDraft ? 'مسودة' : 'ملغاة',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: designMuted,
                                    ),
                                  ),
                                if (t != null && m == 'installments')
                                  Text(
                                    '${t.months} شهور · مقدم ${designMoney(t.upfrontMinor)}',
                                    style: const TextStyle(
                                      color: designMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 92,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            i.formattedNet,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 29,
                        child: _InvoiceMenu(
                          invoice: i,
                          name: names[i.customerId],
                          onSchedule: () => setState(() {
                            tab = 1;
                            query = i.id;
                            page = 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
        else
          for (final d in dues)
            MobileRecordCard(
              onTap: () => openCustomer(d.customerId),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: d.overdueAt(DateTime.now())
                        ? Colors.red
                        : designGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          names[d.customerId] ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'قسط ${d.index} · ${designDate(d.date)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: designMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        designMoney(d.remainingMinor),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        d.remainingMinor == 0
                            ? 'مسدد'
                            : d.overdueAt(DateTime.now())
                            ? 'متأخر'
                            : 'قادم',
                        style: TextStyle(
                          fontSize: 11,
                          color: d.overdueAt(DateTime.now())
                              ? Colors.red
                              : designGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        if (tab == 0 && rows.isEmpty || tab == 1 && dues.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('لا توجد بيانات مطابقة')),
          ),
        MobileLoadMore(
          shown: tab == 0 ? rows.length : dues.length,
          total: tab == 0 ? filtered.length : schedule.length,
          noun: tab == 0 ? 'فاتورة' : 'قسط',
          onMore:
              (tab == 0
                  ? rows.length < filtered.length
                  : dues.length < schedule.length)
              ? () => setState(() => page++)
              : null,
        ),
      ],
    );
  }

  Future<void> _chooseMonth(List<String> months) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('كل الشهور'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            for (final m in months)
              ListTile(title: Text(m), onTap: () => Navigator.pop(context, m)),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        month = value;
        page = 0;
      });
    }
  }
}

class _InvoiceMenu extends StatelessWidget {
  const _InvoiceMenu({
    required this.invoice,
    required this.name,
    required this.onSchedule,
  });
  final InvoiceModel invoice;
  final String? name;
  final VoidCallback onSchedule;
  Future<void> export(bool print) async {
    final items = await InvoiceRepository().getItems(invoice.id);
    final bytes = await PdfService.generateInvoicePdf(
      invoice: invoice,
      customerName: name,
      items: items,
    );
    if (print) {
      await PdfService.printDocument(bytes);
    } else {
      await PdfService.shareDocument(
        bytes,
        filename: 'Invoice_${invoice.id}.pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'إجراءات الفاتورة',
    icon: Icon(
      MediaQuery.sizeOf(context).width < 600
          ? Icons.more_horiz
          : Icons.more_vert,
    ),
    onSelected: (v) async {
      if (v == 'view') {
        Get.toNamed(
          AppRoutes.invoiceDetail,
          arguments: {'invoice_id': invoice.id},
        );
      }
      if (v == 'schedule') onSchedule();
      if (v == 'print' || v == 'export') {
        try {
          await export(v == 'print');
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('تعذر تجهيز المستند')));
          }
        }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'view', child: Text('عرض الفاتورة')),
      PopupMenuItem(value: 'schedule', child: Text('عرض جدول الأقساط')),
      PopupMenuItem(value: 'print', child: Text('طباعة')),
      PopupMenuItem(value: 'export', child: Text('مشاركة PDF')),
    ],
  );
}
