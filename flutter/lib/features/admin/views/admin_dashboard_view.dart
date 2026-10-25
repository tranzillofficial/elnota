import 'release_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/utils/app_routes.dart';
import '../controllers/admin_controller.dart';
import '../repositories/admin_repository.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key, this.gateway});
  final AdminGateway? gateway;
  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final String controllerTag = UniqueKey().toString();
  late final AdminController ctrl = Get.put(
    AdminController(widget.gateway ?? AdminRepository()),
    tag: controllerTag,
  );
  int tab = 0;
  String search = '';
  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  void dispose() {
    Get.delete<AdminController>(tag: controllerTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (ctrl.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!ctrl.allowed.value) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 42),
              const SizedBox(height: 16),
              Text(
                ctrl.error.value ?? 'هذه اللوحة متاحة للمسؤولين المعتمدين فقط',
              ),
              TextButton(
                onPressed: ctrl.refreshData,
                child: const Text('إعادة التحقق'),
              ),
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.login),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        );
      }
      if (tab == 2) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const DesignHeader(
              title: 'الإصدارات والتحميلات',
              subtitle: 'إدارة نسخ التطبيق وروابط المتاجر والملفات المساعدة',
            ),
            const SizedBox(height: 20),
            const ReleaseManager(),
          ],
        );
      }
      if (tab == 3) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const DesignHeader(
              title: 'إعدادات المنصة',
              subtitle: 'الصلاحيات وإدارة التوزيع',
            ),
            DesignPanel(
              title: 'إدارة المنصة',
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حسابك مسؤول معتمد. تُراجع الصلاحيات على السيرفر عند كل إجراء.',
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('حسابات العملاء والاشتراكات'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => setState(() => tab = 0),
                    ),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('طلبات التفعيل'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => setState(() => tab = 1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text(
                        'إصدارات Android وWindows وروابط المتاجر',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => setState(() => tab = 2),
                    ),
                    const Divider(),
                    const Text(
                      'المزامنة مع دفاتر النسخة القديمة غير مفعلة. إدارة المنصة لا تحذف بيانات العملاء.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      final accounts = ctrl.accountRows
          .where(
            (a) => '${a['email']} ${a['business_name']}'.toLowerCase().contains(
              search.toLowerCase(),
            ),
          )
          .toList();
      return ListView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
        ),
        children: [
          DesignHeader(
            title: 'لوحة الإدارة',
            subtitle: 'الحسابات وطلبات التفعيل والاشتراكات',
            actions: [DesignAction('تحديث', Icons.refresh, ctrl.refreshData)],
          ),
          DesignPanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  DesignPill(
                    AdminRepository.writesEnabled
                        ? 'إجراءات بتأكيد المسؤول'
                        : 'وضع القراءة فقط',
                  ),
                  const Text(
                    'لا تتضمن هذه اللوحة حذف الحسابات أو تعديل دفاتر العملاء.',
                    style: TextStyle(color: designMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          DesignStats(
            children: [
              DesignStat(
                'الحسابات المعروضة',
                '${ctrl.accountRows.length}',
                Icons.people_outline,
              ),
              DesignStat(
                'المفعّلة في الصفحة',
                '${ctrl.accountRows.where((a) => a['activated_at'] != null && a['deleted_at'] == null && a['suspended_at'] == null).length}',
                Icons.verified_outlined,
              ),
              DesignStat(
                'طلبات معلقة في الصفحة',
                '${ctrl.requestRows.length}',
                Icons.pending_actions,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('الحسابات')),
                  ButtonSegment(value: 1, label: Text('طلبات التفعيل')),
                ],
                selected: {tab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => tab = v.first),
              ),
              SizedBox(
                width: 340,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث بالبريد أو اسم النشاط',
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ctrl.error.value != null)
            Text(ctrl.error.value!, style: const TextStyle(color: Colors.red)),
          DesignPanel(
            child: tab == 0
                ? DesignTable(
                    minWidth: 1050,
                    rowHeight: 62,
                    headers: const [
                      'النشاط',
                      'البريد',
                      'الحساب',
                      'السحابة حتى',
                      'الطباعة',
                      'الإجراءات',
                      'استثناء المنتجات',
                      'إدارة الحساب والكلاود',
                    ],
                    rows: accounts.map((a) {
                      final active =
                          a['activated_at'] != null &&
                          a['suspended_at'] == null &&
                          a['deleted_at'] == null;
                      return <Widget>[
                        Text(
                          '${a['business_name']}'.isEmpty
                              ? '—'
                              : '${a['business_name']}',
                        ),
                        Text('${a['email']}'),
                        DesignPill(
                          a['deleted_at'] != null
                              ? 'مؤرشف'
                              : a['suspended_at'] != null
                              ? 'موقوف'
                              : active
                              ? 'مفعّل'
                              : 'بانتظار التفعيل',
                          color: active ? designGreen : Colors.orange,
                        ),
                        Text(
                          a['cloud_until'] == null
                              ? '—'
                              : designDate(
                                  DateTime.parse(
                                    a['cloud_until'] as String,
                                  ).toLocal(),
                                ),
                        ),
                        DesignPill(
                          a['printing_enabled'] == true
                              ? 'مفعّلة'
                              : 'غير مفعّلة',
                        ),
                        TextButton(
                          onPressed:
                              !AdminRepository.writesEnabled || ctrl.busy.value
                              ? null
                              : () async {
                                  final enabled = a['printing_enabled'] != true;
                                  if (await confirm(
                                    'صلاحية الطباعة',
                                    '${enabled ? 'تفعيل' : 'إيقاف'} الطباعة للحساب ${a['email']}؟',
                                  )) {
                                    await ctrl.changePrinting(
                                      a['user_id'] as String,
                                      enabled,
                                    );
                                  }
                                },
                          child: const Text('تغيير الطباعة'),
                        ),
                        TextButton(
                          onPressed:
                              !AdminRepository.writesEnabled || ctrl.busy.value
                              ? null
                              : () async {
                                  final enabled = a['catalog_enabled'] != true;
                                  if (await confirm(
                                    'صلاحية المنتجات',
                                    '${enabled ? 'تفعيل' : 'إيقاف'} استثناء المنتجات لهذا الحساب بدون منح كلاود؟',
                                  )) {
                                    await ctrl.changeCatalog(
                                      a['user_id'] as String,
                                      enabled,
                                    );
                                  }
                                },
                          child: Text(
                            a['catalog_enabled'] == true
                                ? 'إيقاف الاستثناء'
                                : 'تفعيل المنتجات',
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled:
                              AdminRepository.writesEnabled && !ctrl.busy.value,
                          tooltip: 'إدارة الحساب',
                          icon: const Icon(Icons.manage_accounts_outlined),
                          itemBuilder: (_) => [
                            if (a['deleted_at'] != null)
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('استعادة الحساب المؤرشف'),
                              )
                            else if (a['suspended_at'] != null)
                              const PopupMenuItem(
                                value: 'resume',
                                child: Text('إلغاء إيقاف الحساب'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'suspend',
                                child: Text('إيقاف الحساب مؤقتًا'),
                              ),
                            if (active) ...const [
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'cloud_month',
                                child: Text('إضافة شهر كلاود — 50 جنيه'),
                              ),
                              PopupMenuItem(
                                value: 'cloud_year',
                                child: Text('إضافة سنة كلاود — 500 جنيه'),
                              ),
                              PopupMenuItem(
                                value: 'cloud_stop',
                                child: Text('إيقاف الكلاود'),
                              ),
                            ],
                          ],
                          onSelected: (operation) async {
                            final title = switch (operation) {
                              'restore' => 'استعادة الحساب',
                              'resume' => 'إلغاء الإيقاف',
                              'suspend' => 'إيقاف الحساب',
                              'cloud_month' => 'إضافة شهر كلاود',
                              'cloud_year' => 'إضافة سنة كلاود',
                              _ => 'إيقاف الكلاود',
                            };
                            if (!await confirm(
                              title,
                              '$title للحساب ${a['email']}؟ لا تتغير بيانات دفتر الحساب. عند منح اشتراك تأكد من مراجعة الدفع أولًا.',
                            )) {
                              return;
                            }
                            if (operation.startsWith('cloud_')) {
                              await ctrl.manageCloud(
                                a['user_id'] as String,
                                operation.substring(6),
                              );
                            } else {
                              await ctrl.manageAccount(
                                a['user_id'] as String,
                                operation,
                              );
                            }
                          },
                        ),
                      ];
                    }).toList(),
                  )
                : DesignTable(
                    minWidth: 1050,
                    rowHeight: 64,
                    headers: const [
                      'الحساب',
                      'الخطة',
                      'المبلغ',
                      'الهاتف',
                      'مرجع الدفع',
                      'المراجعة',
                    ],
                    rows: ctrl.requestRows
                        .map(
                          (r) => <Widget>[
                            Text(
                              ctrl.accountRows
                                          .where(
                                            (a) => a['user_id'] == r['user_id'],
                                          )
                                          .firstOrNull?['email']
                                      as String? ??
                                  '${r['user_id']}',
                            ),
                            Text(
                              r['plan'] == 'basic'
                                  ? 'تفعيل دائم'
                                  : r['plan'] == 'cloud_month'
                                  ? 'سحابة شهرية'
                                  : 'سحابة سنوية',
                            ),
                            Text(
                              r['amount'] == null
                                  ? 'راجع مرجع الدفع'
                                  : designMoney(
                                      (r['amount'] as num).toInt() * 100,
                                    ),
                            ),
                            Text('${r['phone']}'),
                            Text('${r['reference']}'),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final approve in [true, false])
                                  TextButton(
                                    onPressed:
                                        !AdminRepository.writesEnabled ||
                                            ctrl.busy.value
                                        ? null
                                        : () async {
                                            if (await confirm(
                                              approve
                                                  ? 'قبول الطلب'
                                                  : 'رفض الطلب',
                                              'راجع مرجع الدفع ${r['reference']} والحساب ${r['user_id']} قبل التأكيد.',
                                            )) {
                                              await ctrl.reviewRequest(
                                                r['id'] as String,
                                                approve,
                                              );
                                            }
                                          },
                                    child: Text(approve ? 'قبول' : 'رفض'),
                                  ),
                              ],
                            ),
                          ],
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صفحة ${ctrl.page.value + 1} · حتى 50 سجلًا لكل جدول',
                style: const TextStyle(color: designMuted),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: ctrl.page.value == 0
                        ? null
                        : () {
                            ctrl.page.value--;
                            ctrl.refreshData();
                          },
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    onPressed:
                        (tab == 0
                                ? ctrl.accountRows.length
                                : ctrl.requestRows.length) <
                            50
                        ? null
                        : () {
                            ctrl.page.value++;
                            ctrl.refreshData();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    });
    return Scaffold(
      appBar: MediaQuery.sizeOf(context).width < 600
          ? AppBar(
              title: const Text('إدارة المنصة'),
              actions: [
                PopupMenuButton<int>(
                  onSelected: (i) => setState(() => tab = i),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('حسابات العملاء')),
                    PopupMenuItem(value: 1, child: Text('طلبات التفعيل')),
                    PopupMenuItem(
                      value: 2,
                      child: Text('الإصدارات والتحميلات'),
                    ),
                    PopupMenuItem(value: 3, child: Text('إعدادات المنصة')),
                  ],
                ),
                const AccountMenu(),
              ],
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              if (box.maxWidth >= 600)
                DesignSidebar(
                  admin: true,
                  selected: tab,
                  onSelect: (i) => setState(() => tab = i),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
