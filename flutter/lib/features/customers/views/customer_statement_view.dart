import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/statement_pdf_service.dart';
import '../../../core/utils/app_routes.dart';
import '../models/account_statement.dart';
import '../repositories/customer_repository.dart';

class CustomerStatementView extends StatefulWidget {
  const CustomerStatementView({super.key});
  @override
  State<CustomerStatementView> createState() => _CustomerStatementViewState();
}

class _CustomerStatementViewState extends State<CustomerStatementView> {
  late final String customerId =
      (Get.arguments as Map<String, dynamic>?)?['id'] as String? ?? '';
  late final stream = CustomerRepository().watchLedger(customerId);
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime to = DateUtils.dateOnly(DateTime.now());
  late DateTime appliedFrom = from;
  late DateTime appliedTo = to;
  bool exporting = false;
  Future<void> date(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() {
        if (start) {
          from = value;
        } else {
          to = value;
        }
      });
    }
  }

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
          return StreamBuilder<List<StatementMovement>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('تعذر تحميل كشف الحساب'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final statement = AccountStatement(
                movements: snapshot.data!,
                from: appliedFrom,
                to: appliedTo,
              );
              Future<void> export(bool print) async {
                setState(() => exporting = true);
                try {
                  final bytes = await StatementPdfService.generate(
                    name: customer.name,
                    phone: customer.phone,
                    statement: statement,
                  );
                  if (print) {
                    await PdfService.printDocument(
                      bytes,
                      name: 'ElNota Statement',
                    );
                  } else {
                    await PdfService.shareDocument(
                      bytes,
                      filename: 'ElNota_Statement.pdf',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر تجهيز كشف الحساب')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => exporting = false);
                }
              }

              return ListView(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.chevron_right),
                      label: Text('العملاء / ${customer.name} / كشف الحساب'),
                    ),
                  ),
                  DesignHeader(
                    title: 'كشف حساب العميل',
                    subtitle: '${customer.name}  ·  ${customer.phone ?? ''}',
                    actions: [
                      if (exporting)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      else ...[
                        DesignAction(
                          'طباعة كشف الحساب',
                          Icons.print_outlined,
                          () => export(true),
                          primary: true,
                        ),
                        DesignAction(
                          'تصدير PDF',
                          Icons.picture_as_pdf_outlined,
                          () => export(false),
                        ),
                      ],
                    ],
                  ),
                  DesignPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'الفترة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            width: 220,
                            child: LabeledField(
                              'من',
                              child: OutlinedButton.icon(
                                onPressed: () => date(true),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(designDate(from)),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: LabeledField(
                              'إلى',
                              child: OutlinedButton.icon(
                                onPressed: () => date(false),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(designDate(to)),
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => setState(() {
                              final now = DateTime.now();
                              from = DateTime(now.year, now.month);
                              to = DateUtils.dateOnly(now);
                              appliedFrom = from;
                              appliedTo = to;
                            }),
                            child: const Text('هذا الشهر'),
                          ),
                          FilledButton(
                            onPressed: to.isBefore(from)
                                ? null
                                : () => setState(() {
                                    appliedFrom = from;
                                    appliedTo = to;
                                  }),
                            child: const Text('عرض'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DesignStats(
                    children: [
                      DesignStat(
                        'رصيد أول الفترة',
                        designMoney(statement.openingMinor),
                        Icons.history,
                      ),
                      DesignStat(
                        'إجمالي المدين',
                        designMoney(statement.debitMinor),
                        Icons.description_outlined,
                      ),
                      DesignStat(
                        'إجمالي الدائن',
                        designMoney(statement.creditMinor),
                        Icons.account_balance_wallet_outlined,
                      ),
                      DesignStat(
                        'رصيد آخر الفترة',
                        designMoney(statement.closingMinor),
                        Icons.bar_chart,
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DesignPanel(
                    title: 'حركة الحساب',
                    action: Text(
                      '${statement.lines.length} حركات',
                      style: const TextStyle(color: designMuted),
                    ),
                    child: Column(
                      children: [
                        DesignTable(
                          minWidth: 1000,
                          rowHeight: 48,
                          headers: const [
                            'التاريخ',
                            'البيان',
                            'رقم المرجع',
                            'مدين',
                            'دائن',
                            'الرصيد',
                          ],
                          rows: statement.lines.map((line) {
                            final m = line.movement;
                            return <Widget>[
                              Text(designDate(m.date)),
                              Text(m.label),
                              Text(
                                m.reference.length > 8
                                    ? m.reference.substring(0, 8)
                                    : m.reference,
                                style: const TextStyle(color: designMuted),
                              ),
                              Text(
                                m.debitMinor == 0
                                    ? '—'
                                    : designMoney(m.debitMinor),
                              ),
                              Text(
                                m.creditMinor == 0
                                    ? '—'
                                    : designMoney(m.creditMinor),
                                style: const TextStyle(
                                  color: designGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    designMoney(line.balanceMinor),
                                    style: TextStyle(
                                      color: line.balanceMinor < 0
                                          ? designGreen
                                          : null,
                                    ),
                                  ),
                                  if (line.balanceMinor < 0)
                                    const Text(
                                      'رصيد لصالح العميل',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: designGreen,
                                      ),
                                    ),
                                ],
                              ),
                            ];
                          }).toList(),
                        ),
                        if (statement.lines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Text('لا توجد حركات في الفترة المحددة'),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'المدين يزيد المستحق، والدائن يخفضه. القيم مأخوذة من سجل الحساب المرحّل.',
                      style: TextStyle(color: designMuted, fontSize: 12),
                    ),
                  ),
                  DesignPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 20,
                        children: [
                          const Text('المبلغ المستحق على العميل الآن'),
                          Text(
                            designMoney(
                              data.balances[customerId]?.outstandingMinor ?? 0,
                            ),
                            style: const TextStyle(
                              color: designGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            if (box.maxWidth >= 600)
              DesignSidebar(
                selected: 1,
                onSelect: (i) =>
                    Get.offAllNamed(AppRoutes.home, arguments: {'tab': i}),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
