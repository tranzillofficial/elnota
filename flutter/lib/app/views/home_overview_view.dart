import '../../core/widgets/mobile_design.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/invoices/models/invoice_terms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/design_widgets.dart';
import '../../core/widgets/sync_status_badge.dart';
import '../../core/utils/app_routes.dart';

class HomeOverviewView extends StatefulWidget {
  const HomeOverviewView({super.key});
  @override
  State<HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends State<HomeOverviewView> {
  int activityFilter = 0;
  int chartDays = 7;
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AccountDataBuilder(
        builder: (context, data) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayCollected = data.payments
              .where(
                (p) =>
                    !p.paymentDate.isBefore(today) &&
                    p.paymentDate.isBefore(today.add(const Duration(days: 1))),
              )
              .fold<int>(0, (sum, p) => sum + p.amountMinor);
          final collected = data.balances.values.fold<int>(
            0,
            (sum, b) => sum + b.totalPaymentsMinor,
          );
          final outstanding = data.balances.values.fold<int>(
            0,
            (sum, b) => sum + (b.outstandingMinor > 0 ? b.outstandingMinor : 0),
          );
          final names = {for (final c in data.customers) c.id: c.name};
          final activities =
              [
                    for (final i in data.invoices)
                      (
                        i.customerId,
                        names[i.customerId] ?? '—',
                        'فاتورة',
                        i.invoiceDate,
                        i.netMinor,
                        i.id,
                        i.isPosted ? 'مرحّلة' : 'مسودة',
                      ),
                    for (final p in data.payments)
                      (
                        p.customerId,
                        names[p.customerId] ?? '—',
                        'دفعة نقدية',
                        p.paymentDate,
                        p.amountMinor,
                        p.id,
                        'مسجلة',
                      ),
                  ]
                  .where(
                    (a) =>
                        (activityFilter == 0 ||
                            activityFilter == 1 && a.$3 == 'فاتورة' ||
                            activityFilter == 2 && a.$3 != 'فاتورة') &&
                        (a.$2.contains(query) || a.$6.contains(query)),
                  )
                  .toList()
                ..sort((a, b) => b.$4.compareTo(a.$4));
          final recent = DesignPanel(
            title: 'آخر العمليات',
            action: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('الكل')),
                ButtonSegment(value: 1, label: Text('فواتير')),
                ButtonSegment(value: 2, label: Text('مدفوعات')),
              ],
              selected: {activityFilter},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  setState(() => activityFilter = v.first),
            ),
            child: Column(
              children: [
                DesignTable(
                  minWidth: 650,
                  rowHeight: 42,
                  headers: const [
                    'العميل',
                    'العملية',
                    'التاريخ والوقت',
                    'المبلغ',
                    'الحالة',
                  ],
                  rows: activities
                      .take(6)
                      .map(
                        (a) => <Widget>[
                          InkWell(
                            onTap: () => openCustomer(a.$1),
                            child: Text(a.$2),
                          ),
                          Text(a.$3),
                          Text(
                            designDate(a.$4),
                            style: const TextStyle(color: designMuted),
                          ),
                          Text(designMoney(a.$5)),
                          DesignPill(
                            a.$7,
                            color: a.$3 == 'فاتورة' ? designMuted : designGreen,
                          ),
                        ],
                      )
                      .toList(),
                ),
                if (activities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('لا توجد عمليات مسجلة'),
                  ),
              ],
            ),
          );
          final upcoming = data.dues.where((d) => d.remainingMinor > 0).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final due = DesignPanel(
            title: 'أقساط قريبة ومتأخرة',
            action: TextButton(
              onPressed: () => Get.toNamed(
                AppRoutes.invoices,
                arguments: {'installments': true},
              ),
              child: const Text('عرض الكل'),
            ),
            child: DesignTable(
              minWidth: 470,
              rowHeight: 48,
              headers: const ['العميل', 'تاريخ الاستحقاق', 'المبلغ', 'الحالة'],
              rows: upcoming
                  .take(4)
                  .map(
                    (d) => <Widget>[
                      Text(names[d.customerId] ?? '—'),
                      Text(designDate(d.date)),
                      Text(designMoney(d.remainingMinor)),
                      DesignPill(
                        d.overdueAt(now) ? 'متأخر' : 'قريب',
                        color: d.overdueAt(now) ? Colors.red : Colors.orange,
                      ),
                    ],
                  )
                  .toList(),
            ),
          );
          final balances =
              data.customers
                  .where((c) => data.balances.containsKey(c.id))
                  .toList()
                ..sort(
                  (a, b) => data.balances[b.id]!.outstandingMinor.compareTo(
                    data.balances[a.id]!.outstandingMinor,
                  ),
                );
          final balancePanel = DesignPanel(
            title: 'أرصدة العملاء',
            action: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.customers),
              child: const Text('عرض الكل'),
            ),
            child: DesignTable(
              minWidth: 400,
              rowHeight: 42,
              headers: const ['العميل', 'الرصيد المستحق', ''],
              rows: balances
                  .take(4)
                  .map(
                    (c) => <Widget>[
                      InkWell(
                        onTap: () => openCustomer(c.id),
                        child: Row(
                          children: [
                            DesignAvatar(c.name),
                            const SizedBox(width: 12),
                            Text(c.name),
                          ],
                        ),
                      ),
                      Text(
                        designMoney(data.balances[c.id]!.outstandingMinor),
                        style: TextStyle(
                          color: data.balances[c.id]!.outstandingMinor > 0
                              ? Colors.red
                              : designGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => openCustomer(c.id),
                        tooltip: 'عرض الحساب',
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  )
                  .toList(),
            ),
          );
          if (MediaQuery.sizeOf(context).width < 600) {
            return _mobile(
              data,
              outstanding,
              todayCollected,
              activities,
              upcoming,
              names,
            );
          }
          final daily = List.generate(chartDays, (i) {
            final date = today.subtract(Duration(days: chartDays - i - 1));
            final end = date.add(const Duration(days: 1));
            return (
              date,
              data.payments
                  .where(
                    (p) =>
                        !p.paymentDate.isBefore(date) &&
                        p.paymentDate.isBefore(end),
                  )
                  .fold<int>(0, (sum, p) => sum + p.amountMinor),
            );
          });
          final chart = DesignPanel(
            title: 'حركة التحصيل',
            action: DropdownButton<int>(
              value: chartDays,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 7, child: Text('آخر 7 أيام')),
                DropdownMenuItem(value: 14, child: Text('آخر 14 يوم')),
              ],
              onChanged: (v) => setState(() => chartDays = v!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _CollectionChart(values: daily),
            ),
          );
          return ListView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 30,
            ),
            children: [
              DesignHeader(
                title: 'الرئيسية',
                subtitle: 'نظرة على حساباتك اليوم',
                actions: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width < 760
                            ? 240
                            : 460,
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'ابحث عن عميل أو فاتورة...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: [
                          const SyncStatusBadge(),
                          DesignAction(
                            'عميل جديد',
                            Icons.person_add_outlined,
                            () => Get.toNamed(AppRoutes.customerCreate),
                          ),
                          DesignAction(
                            'تسجيل دفعة',
                            Icons.payment_outlined,
                            () => Get.toNamed(AppRoutes.paymentCreate),
                          ),
                          DesignAction(
                            'فاتورة جديدة',
                            Icons.add,
                            () => Get.toNamed(AppRoutes.invoiceCreate),
                            primary: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              DesignStats(
                children: [
                  DesignStat(
                    'إجمالي المستحق',
                    designMoney(outstanding),
                    Icons.payment,
                    highlight: true,
                  ),
                  DesignStat(
                    'تحصيل اليوم',
                    designMoney(todayCollected),
                    Icons.download_outlined,
                  ),
                  DesignStat(
                    'إجمالي المحصل',
                    designMoney(collected),
                    Icons.check_circle_outline,
                  ),
                  DesignStat(
                    'عدد العملاء',
                    '${data.customers.length}',
                    Icons.people_outline,
                  ),
                  DesignStat(
                    'أقساط هذا الشهر',
                    designMoney(
                      data.dues
                          .where(
                            (d) =>
                                d.date.year == now.year &&
                                d.date.month == now.month,
                          )
                          .fold<int>(0, (sum, d) => sum + d.remainingMinor),
                    ),
                    Icons.calendar_month_outlined,
                  ),
                  DesignStat(
                    'مبالغ متأخرة',
                    designMoney(
                      data.dues
                          .where((d) => d.overdueAt(now))
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
                builder: (context, box) => box.maxWidth >= 1150
                    ? Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: recent),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: due),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: chart),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: balancePanel),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          recent,
                          const SizedBox(height: 18),
                          chart,
                          const SizedBox(height: 18),
                          balancePanel,
                          const SizedBox(height: 18),
                          due,
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget _mobile(
    AccountData data,
    int outstanding,
    int collectedToday,
    List<(String, String, String, DateTime, int, String, String)> activities,
    List<ScheduledDue> upcoming,
    Map<String, String> names,
  ) {
    final now = DateTime.now();
    final late = data.dues.where((d) => d.overdueAt(now)).toList();
    final monthDues = data.dues
        .where((d) => d.date.year == now.year && d.date.month == now.month)
        .fold<int>(0, (sum, d) => sum + d.remainingMinor);
    final name = Get.isRegistered<AuthService>()
        ? AuthService.to.currentSession.value?.workspaceName
        : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          name == null ? 'أهلًا بيك' : 'أهلًا، $name',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(
          designDate(now),
          style: const TextStyle(color: designMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        MobileStat(
          'إجمالي المستحق',
          designMoney(outstanding),
          Icons.account_balance_wallet_outlined,
          large: true,
          subtitle: 'الرصيد المتبقي لدى العملاء',
        ),
        const SizedBox(height: 10),
        MobileStatRow(
          children: [
            MobileStat(
              'متأخرات',
              designMoney(
                late.fold<int>(0, (sum, d) => sum + d.remainingMinor),
              ),
              Icons.access_time,
              color: Colors.red,
            ),
            MobileStat(
              'أقساط الشهر',
              designMoney(monthDues),
              Icons.calendar_month_outlined,
            ),
            MobileStat(
              'تحصيل اليوم',
              designMoney(collectedToday),
              Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'اختصارات سريعة',
          style: TextStyle(color: designMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.paymentCreate),
                icon: const Icon(Icons.payment_outlined, size: 21),
                label: const Text('تسجيل دفعة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.customerCreate),
                icon: const Icon(Icons.person_add_outlined, size: 21),
                label: const Text('عميل جديد'),
              ),
            ),
          ],
        ),
        MobileSectionTitle(
          'أقساط قريبة ومتأخرة',
          onAll: () => Get.toNamed(
            AppRoutes.invoices,
            arguments: {'installments': true},
          ),
        ),
        DesignPanel(
          child: Column(
            children: [
              for (final d in upcoming.take(3))
                Builder(
                  builder: (context) {
                    final days =
                        DateTime.utc(d.date.year, d.date.month, d.date.day)
                            .difference(
                              DateTime.utc(now.year, now.month, now.day),
                            )
                            .inDays;
                    final color = d.overdueAt(now)
                        ? Colors.red
                        : days == 0
                        ? Colors.orange
                        : designMuted;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      onTap: () => openCustomer(d.customerId),
                      leading: Icon(
                        Icons.event_outlined,
                        color: color,
                        size: 23,
                      ),
                      title: Text(
                        names[d.customerId] ?? '—',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        days < 0
                            ? 'متأخر ${-days} أيام'
                            : days == 0
                            ? 'يستحق اليوم'
                            : days == 1
                            ? 'غدًا'
                            : 'بعد $days أيام',
                        style: TextStyle(color: color, fontSize: 11),
                      ),
                      trailing: Text(
                        designMoney(d.remainingMinor),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    );
                  },
                ),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'لا توجد أقساط مستحقة',
                    style: TextStyle(color: designMuted),
                  ),
                ),
            ],
          ),
        ),
        MobileSectionTitle(
          'آخر العمليات',
          onAll: () => Get.toNamed(AppRoutes.payments),
        ),
        DesignPanel(
          child: Column(
            children: [
              for (final a in activities.take(3))
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  onTap: () => openCustomer(a.$1),
                  leading: Icon(
                    a.$3 == 'فاتورة'
                        ? Icons.description_outlined
                        : Icons.arrow_upward,
                    color: a.$3 == 'فاتورة' ? designMuted : designGreen,
                    size: 24,
                  ),
                  title: Text(
                    a.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${a.$3} · ${designDate(a.$4)}',
                    style: const TextStyle(color: designMuted, fontSize: 10),
                  ),
                  trailing: Text(
                    '${a.$3 == 'فاتورة' ? '' : '+'}${designMoney(a.$5)}',
                    style: TextStyle(
                      color: a.$3 == 'فاتورة' ? designInk : designGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'لا توجد عمليات مسجلة',
                    style: TextStyle(color: designMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionChart extends StatelessWidget {
  const _CollectionChart({required this.values});
  final List<(DateTime, int)> values;
  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (m, v) => v.$2 > m ? v.$2 : m);
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        textDirection: TextDirection.ltr,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      child: Text(
                        designMoney(v.$2),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: max == 0 ? 2 : 150 * v.$2 / max + 2,
                      constraints: const BoxConstraints(maxWidth: 54),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF37BF91), Color(0xFF16A56F)],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${v.$1.day}/${v.$1.month}',
                      style: const TextStyle(fontSize: 12, color: designMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
