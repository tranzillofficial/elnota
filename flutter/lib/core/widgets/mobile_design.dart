import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_routes.dart';
import 'design_widgets.dart';

class MobileBrandHeader extends StatelessWidget {
  const MobileBrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 38,
          height: 38,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        const Text(
          'النوتة',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: designInk,
          ),
        ),
        const Spacer(),
        const AccountMenu(),
        IconButton(
          tooltip: 'الاستحقاقات',
          onPressed: () => Get.toNamed(
            AppRoutes.invoices,
            arguments: {'installments': true},
          ),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: designMuted,
            size: 27,
          ),
        ),
      ],
    ),
  );
}

class MobileStat extends StatelessWidget {
  const MobileStat(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.color = designGreen,
    this.large = false,
    this.subtitle,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final bool large;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(large ? 16 : 10),
    constraints: BoxConstraints(minHeight: large ? 116 : 88),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .035),
      border: Border.all(color: color.withValues(alpha: .16)),
      borderRadius: BorderRadius.circular(9),
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
                  color: color == Colors.red
                      ? const Color(0xFF912B2B)
                      : designMuted,
                  fontSize: large ? 15 : 11,
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, color: color, size: large ? 29 : 20),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: TextStyle(
              fontSize: large ? 30 : 20,
              fontWeight: FontWeight.w800,
              color: large || color != Colors.blue ? color : designInk,
            ),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: designMuted),
          ),
      ],
    ),
  );
}

class MobileStatRow extends StatelessWidget {
  const MobileStatRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: children[i]),
      ],
    ],
  );
}

class MobileFilters<T> extends StatelessWidget {
  const MobileFilters({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });
  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in values) ...[
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 7),
            child: OutlinedButton(
              onPressed: () => onChanged(item.$1),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                minimumSize: const Size(0, 38),
                backgroundColor: selected == item.$1
                    ? designGreen
                    : const Color(0xFFF7F8FB),
                foregroundColor: selected == item.$1
                    ? Colors.white
                    : designMuted,
                side: BorderSide(
                  color: selected == item.$1 ? designGreen : designBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(item.$2, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ),
      ],
      ?trailing,
    ],
  );
}

class MobileRecordCard extends StatelessWidget {
  const MobileRecordCard({
    super.key,
    required this.child,
    this.onTap,
    this.highlight = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: highlight
          ? const Color(0xFFF2FAF7)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: designBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: child,
        ),
      ),
    ),
  );
}

class MobileLoadMore extends StatelessWidget {
  const MobileLoadMore({
    super.key,
    required this.shown,
    required this.total,
    required this.noun,
    this.onMore,
  });
  final int shown, total;
  final String noun;
  final VoidCallback? onMore;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      children: [
        Text(
          'عرض $shown من $total $noun',
          style: const TextStyle(fontSize: 12, color: designMuted),
        ),
        if (onMore != null)
          TextButton.icon(
            onPressed: onMore,
            icon: const Icon(Icons.expand_more, size: 20),
            label: const Text('تحميل المزيد'),
          ),
      ],
    ),
  );
}

class MobileSectionTitle extends StatelessWidget {
  const MobileSectionTitle(this.title, {super.key, this.onAll});
  final String title;
  final VoidCallback? onAll;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (onAll != null)
          TextButton(onPressed: onAll, child: const Text('عرض الكل ‹')),
      ],
    ),
  );
}
