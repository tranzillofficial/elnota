import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/services/account_access_service.dart';
import '../../core/services/daily_backup_service.dart';
import '../../features/auth/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/design_widgets.dart';
import '../../core/widgets/mobile_design.dart';

class MobileMoreView extends StatelessWidget {
  const MobileMoreView({super.key, required this.onSelect});
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final session = auth?.currentSession.value;
    final active =
        Get.isRegistered<AccountAccessService>() &&
        AccountAccessService.to.access.value.active;
    final last = Get.isRegistered<DailyBackupService>()
        ? Get.find<DailyBackupService>().lastUploaded.value
        : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'المزيد',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 14),
        MobileRecordCard(
          highlight: true,
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 36,
                color: designGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.workspaceName ?? 'الحساب',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      session?.email ?? 'دون تسجيل دخول',
                      style: const TextStyle(color: designMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              DesignPill(
                active ? 'مفعّل' : 'محلي',
                color: active ? designGreen : designMuted,
              ),
            ],
          ),
        ),
        const MobileSectionTitle('إدارة النشاط'),
        _grid(context, [
          ('الرئيسية', Icons.dashboard_outlined, () => onSelect(0)),
          ('العملاء', Icons.people_outline, () => onSelect(1)),
          (
            'المدفوعات',
            Icons.account_balance_wallet_outlined,
            () => onSelect(3),
          ),
          ('المنتجات', Icons.inventory_2_outlined, () => onSelect(5)),
          ('النسخ الاحتياطي', Icons.cloud_upload_outlined, () => onSelect(4)),
          ('الطباعة', Icons.print_outlined, () => onSelect(4)),
        ]),
        const MobileSectionTitle('الحساب والمساعدة'),
        _grid(context, [
          ('الإعدادات', Icons.tune, () => onSelect(4)),
          (
            'المساعدة',
            Icons.chat_bubble_outline,
            () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('المساعدة'),
                content: const Text(
                  'من العملاء افتح الحساب لإضافة الفواتير والدفعات. الفواتير تدعم النقدي والآجل والأقساط، وتُخصم الدفعات من أقدم استحقاق أولًا.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسنًا'),
                  ),
                ],
              ),
            ),
          ),
          (
            'عن التطبيق',
            Icons.menu_book_outlined,
            () async {
              final info = await PackageInfo.fromPlatform();
              if (context.mounted) {
                showAboutDialog(
                  context: context,
                  applicationName: 'ElNota',
                  applicationVersion: info.version,
                  applicationIcon: Image.asset(
                    'assets/images/logo.png',
                    width: 44,
                    height: 44,
                  ),
                );
              }
            },
          ),
        ]),
        const SizedBox(height: 18),
        MobileRecordCard(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await auth?.signOut();
                  Get.offAllNamed(AppRoutes.login);
                },
                icon: const Icon(Icons.logout, size: 19, color: Colors.red),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_outlined,
                    size: 21,
                    color: designMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    last == null
                        ? 'لم تُرفع نسخة احتياطية'
                        : 'آخر نسخة: ${designDate(last)}',
                    style: const TextStyle(color: designMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    List<(String, IconData, VoidCallback)> items,
  ) => LayoutBuilder(
    builder: (context, box) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          SizedBox(
            width: (box.maxWidth - 16) / 3,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: designBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.$3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 3,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE6F8EF), Color(0xFFF7FFFB)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.$2, size: 33, color: designGreen),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
