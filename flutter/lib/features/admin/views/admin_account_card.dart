import 'package:flutter/material.dart';

import '../../../core/widgets/design_widgets.dart';

class AdminAccountCard extends StatelessWidget {
  const AdminAccountCard({
    super.key,
    required this.account,
    required this.enabled,
    required this.onAction,
  });
  final Map<String, dynamic> account;
  final bool enabled;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final active =
        account['activated_at'] != null &&
        account['suspended_at'] == null &&
        account['deleted_at'] == null;
    final until = DateTime.tryParse(account['cloud_until'] as String? ?? '');
    final cloud = active && until != null && until.isAfter(DateTime.now());
    final catalog = active && (account['catalog_enabled'] as bool? ?? cloud);
    final printing = account['printing_enabled'] == true;
    Widget action(String label, String operation, {bool available = true}) =>
        OutlinedButton(
          onPressed: enabled && available ? () => onAction(operation) : null,
          child: Text(label),
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${account['business_name'] ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(
            '${account['email']}',
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              DesignPill(
                account['deleted_at'] != null
                    ? 'مؤرشف'
                    : account['suspended_at'] != null
                    ? 'الحساب موقوف'
                    : active
                    ? 'الحساب مفعّل'
                    : 'بانتظار التفعيل',
              ),
              DesignPill(cloud ? 'الكلاود نشط' : 'الكلاود غير نشط'),
              DesignPill(catalog ? 'المخزون مفعّل' : 'المخزون غير مفعّل'),
              DesignPill(printing ? 'الطباعة مفعّلة' : 'الطباعة غير مفعّلة'),
            ],
          ),
          if (until != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('انتهاء الكلاود: ${designDate(until.toLocal())}'),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              action(
                'تفعيل / تجديد الكلاود شهريًا',
                'cloud_month',
                available: active,
              ),
              action(
                'تفعيل / تجديد الكلاود سنويًا',
                'cloud_year',
                available: active,
              ),
              action('إيقاف الكلاود', 'cloud_stop', available: cloud),
              action(
                catalog ? 'إيقاف المخزون' : 'تفعيل المخزون',
                catalog ? 'catalog_off' : 'catalog_on',
                available: active,
              ),
              action(
                printing ? 'إيقاف الطباعة' : 'تفعيل الطباعة',
                printing ? 'printing_off' : 'printing_on',
                available: active,
              ),
              if (account['deleted_at'] != null)
                action('استعادة الحساب', 'restore')
              else if (account['suspended_at'] != null)
                action('إعادة تشغيل الحساب', 'resume')
              else
                action('إيقاف الحساب', 'suspend', available: active),
            ],
          ),
          const Divider(height: 28),
        ],
      ),
    );
  }
}
