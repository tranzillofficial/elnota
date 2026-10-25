import '../../features/auth/services/auth_service.dart';
import '../../features/invoices/models/invoice_terms.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/customers/models/customer_model.dart';
import '../../features/customers/repositories/customer_repository.dart';
import '../../features/invoices/models/invoice_model.dart';
import '../../features/invoices/repositories/invoice_repository.dart';
import '../../features/payments/models/payment_model.dart';
import '../../features/payments/repositories/payment_repository.dart';
import '../utils/money_utils.dart';
import '../utils/app_routes.dart';

const designGreen = Color(0xFF00845B);
const designInk = Color(0xFF101326);
const designMuted = Color(0xFF59698D);
const designBorder = Color(0xFFE4E9F2);

String designDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
String designMoney(int amount) => MoneyUtils.formatMinor(amount);

/// Owns presentation subscriptions; balances come from the existing ledger repository.
class AccountData extends ChangeNotifier {
  final customers = <CustomerModel>[];
  final invoices = <InvoiceModel>[];
  final payments = <PaymentModel>[];
  final terms = <InvoiceTerms>[];
  List<ScheduledDue> get dues =>
      [
            for (final customer in customers)
              ...allocateCustomerDues(
                invoices: invoices
                    .where((i) => i.customerId == customer.id)
                    .toList(),
                terms: terms.where((t) => t.customerId == customer.id).toList(),
                outstandingMinor: balances[customer.id]?.outstandingMinor ?? 0,
              ),
          ]
          .where(
            (d) => terms.any(
              (t) => t.invoiceId == d.invoiceId && t.method == 'installments',
            ),
          )
          .toList();
  final balances = <String, CustomerBalanceSummary>{};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, StreamSubscription<CustomerBalanceSummary>>
  _balanceSubscriptions = {};
  bool loading = true;
  String? error;
  AccountData() {
    _subscriptions.add(
      InvoiceRepository().watchTerms().listen((rows) {
        terms
          ..clear()
          ..addAll(rows);
        notifyListeners();
      }, onError: _fail),
    );

    _subscriptions.add(
      CustomerRepository().watchAll().listen((rows) {
        customers
          ..clear()
          ..addAll(rows);
        final ids = rows.map((c) => c.id).toSet();
        for (final id in _balanceSubscriptions.keys.toList()) {
          if (!ids.contains(id)) {
            _balanceSubscriptions.remove(id)?.cancel();
            balances.remove(id);
          }
        }
        for (final c in rows) {
          _balanceSubscriptions.putIfAbsent(
            c.id,
            () => CustomerRepository().watchBalance(c.id).listen((b) {
              balances[c.id] = b;
              notifyListeners();
            }, onError: _fail),
          );
        }
        loading = false;
        notifyListeners();
      }, onError: _fail),
    );
    _subscriptions.add(
      InvoiceRepository().watchAll().listen((rows) {
        invoices
          ..clear()
          ..addAll(rows);
        notifyListeners();
      }, onError: _fail),
    );
    _subscriptions.add(
      PaymentRepository().watchAll().listen((rows) {
        payments
          ..clear()
          ..addAll(rows);
        notifyListeners();
      }, onError: _fail),
    );
  }
  void _fail(Object e) {
    error = 'تعذر تحميل البيانات';
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in [..._subscriptions, ..._balanceSubscriptions.values]) {
      sub.cancel();
    }
    super.dispose();
  }
}

class AccountDataBuilder extends StatefulWidget {
  const AccountDataBuilder({super.key, required this.builder});
  final Widget Function(BuildContext, AccountData) builder;
  @override
  State<AccountDataBuilder> createState() => _AccountDataBuilderState();
}

class _AccountDataBuilderState extends State<AccountDataBuilder> {
  late final AccountData data = AccountData();
  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: data,
    builder: (context, _) {
      if (data.error != null) {
        return Center(child: Text(data.error!));
      }
      if (data.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.builder(context, data);
    },
  );
}

class DesignPanel extends StatelessWidget {
  const DesignPanel({super.key, this.title, this.action, required this.child});
  final String? title;
  final Widget? action;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final heading = Text(
                  title!,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 16 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                );
                if (box.maxWidth < 260) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      if (action != null) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: action!,
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    ?action,
                  ],
                );
              },
            ),
          ),
        Material(color: Colors.transparent, child: child),
      ],
    ),
  );
}

class DesignHeader extends StatelessWidget {
  const DesignHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 23 : 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: TextStyle(
                color: designMuted,
                fontSize: MediaQuery.sizeOf(context).width < 600 ? 12 : 17,
              ),
            ),
          ],
        ],
      );
      final buttons = Wrap(spacing: 12, runSpacing: 10, children: actions);
      return Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: box.maxWidth < 1000
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 16), buttons],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  buttons,
                ],
              ),
      );
    },
  );
}

class DesignAction extends StatelessWidget {
  const DesignAction(
    this.label,
    this.icon,
    this.onPressed, {
    super.key,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 22), const SizedBox(width: 10), Text(label)],
    );
    return primary
        ? FilledButton(
            onPressed: onPressed,
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          );
  }
}

class DesignStats extends StatelessWidget {
  const DesignStats({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count =
          MediaQuery.sizeOf(context).width < 600 && box.maxWidth >= 280
          ? (children.length == 3 ? 3 : 2)
          : box.maxWidth >= 1100
          ? children.length
          : box.maxWidth >= 650
          ? 3
          : box.maxWidth >= 400
          ? 2
          : 1;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: children
            .map(
              (child) => SizedBox(
                width: (box.maxWidth - (count - 1) * 14) / count,
                child: child,
              ),
            )
            .toList(),
      );
    },
  );
}

class DesignStat extends StatelessWidget {
  const DesignStat(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.color,
    this.highlight = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? designGreen;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 85 : 130),
      padding: EdgeInsets.all(mobile ? 10 : 20),
      decoration: BoxDecoration(
        color: highlight
            ? tone.withValues(alpha: .045)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlight
              ? tone.withValues(alpha: .3)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: designMuted,
                    fontSize: mobile ? 11 : 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: tone, size: mobile ? 18 : 25),
              ),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: mobile ? 21 : 26,
                fontWeight: FontWeight.w800,
                color: highlight ? tone : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DesignPill extends StatelessWidget {
  const DesignPill(this.label, {super.key, this.color = designGreen});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 13)),
  );
}

class DesignTable extends StatelessWidget {
  const DesignTable({
    super.key,
    required this.headers,
    required this.rows,
    this.minWidth = 650,
    this.rowHeight = 54,
  });
  final List<String> headers;
  final List<List<Widget>> rows;
  final double minWidth;
  final double rowHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => MediaQuery.sizeOf(context).width < 600
        ? Column(
            children: [
              for (final row in rows)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: designBorder)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < row.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (i < headers.length && headers[i].isNotEmpty)
                                SizedBox(
                                  width: 85,
                                  child: Text(
                                    headers[i],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: designMuted,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: DefaultTextStyle.merge(
                                  style: const TextStyle(fontSize: 12),
                                  child: row[i],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: box.maxWidth < minWidth ? minWidth : box.maxWidth,
              ),
              child: DataTable(
                headingRowHeight: 47,
                dataRowMinHeight: rowHeight,
                dataRowMaxHeight: rowHeight,
                horizontalMargin: 20,
                columnSpacing: 20,
                dividerThickness: .6,
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                ),
                headingTextStyle: const TextStyle(
                  color: designMuted,
                  fontSize: 14,
                ),
                columns: headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: rows
                    .map(
                      (row) =>
                          DataRow(cells: row.map((w) => DataCell(w)).toList()),
                    )
                    .toList(),
              ),
            ),
          ),
  );
}

class DesignAvatar extends StatelessWidget {
  const DesignAvatar(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 23,
    backgroundColor: const Color(0xFFE8F2FF),
    foregroundColor: const Color(0xFF1464FA),
    child: Text(
      name
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .take(2)
          .map((s) => s[0])
          .join(' '),
    ),
  );
}

void openCustomer(String id) =>
    Get.toNamed(AppRoutes.customerDetail, arguments: {'id': id});
void customerAction(String route, String id) =>
    Get.toNamed(route, arguments: {'customer_id': id});

class DesignSidebar extends StatelessWidget {
  const DesignSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.admin = false,
  });
  final int selected;
  final bool admin;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final icons = admin
        ? [
            Icons.people_outline,
            Icons.verified_user_outlined,
            Icons.download_outlined,
            Icons.tune,
          ]
        : [
            Icons.home_rounded,
            Icons.people_outline,
            Icons.description_outlined,
            Icons.payment_outlined,
            Icons.settings_outlined,
            Icons.inventory_2_outlined,
          ];
    final labels = admin
        ? [
            'حسابات العملاء',
            'طلبات التفعيل',
            'الإصدارات والتحميلات',
            'إعدادات المنصة',
          ]
        : [
            'الرئيسية',
            'العملاء',
            'الفواتير',
            'الدفعات',
            'الإعدادات',
            'المنتجات',
          ];
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00815D), Color(0xFF00734F)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Image.asset(
              'assets/images/logo.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final i in (admin ? [0, 1, 2, 3] : [0, 1, 2, 3, 5, 4]))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Tooltip(
                          message: labels[i],
                          child: Material(
                            color: selected == i
                                ? const Color(0xFF15A16E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => onSelect(i),
                              child: SizedBox(
                                width: 46,
                                height: 44,
                                child: Icon(
                                  icons[i],
                                  size: 23,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AccountMenu(),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final session = auth?.currentSession.value;
    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      position: PopupMenuPosition.over,
      onSelected: (value) async {
        if (value == 'logout') {
          await auth?.signOut();
          Get.offAllNamed(AppRoutes.login);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session?.workspaceName ?? 'الحساب',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                session?.email ?? 'غير مسجل',
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Text('تسجيل الخروج'),
            ],
          ),
        ),
      ],
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: Icon(Icons.person_outline, color: Color(0xFF59698D), size: 23),
      ),
    );
  }
}
