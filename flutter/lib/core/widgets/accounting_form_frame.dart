import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountingFormFrame extends StatelessWidget {
  const AccountingFormFrame({
    super.key,
    required this.title,
    required this.child,
    required this.footer,
    this.width = 680,
    this.busy = false,
  });
  final String title;
  final Widget child;
  final Widget footer;
  final double width;
  final bool busy;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: LayoutBuilder(
      builder: (context, box) {
        final mobile = box.maxWidth < 600;
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 10 : 22,
                12,
                mobile ? 10 : 22,
                8,
              ),
              child: Row(
                children: [
                  if (mobile)
                    IconButton(
                      tooltip: 'رجوع',
                      onPressed: busy ? null : () => Get.back(),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (mobile)
                    Image.asset('assets/images/logo.png', width: 38, height: 38)
                  else
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: busy ? null : () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 24,
                  vertical: 8,
                ),
                child: child,
              ),
            ),
            Container(
              padding: EdgeInsets.all(mobile ? 12 : 24),
              decoration: mobile
                  ? BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    )
                  : null,
              child: footer,
            ),
          ],
        );
        if (mobile) {
          return Scaffold(
            body: SafeArea(
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: Theme.of(
                    context,
                  ).inputDecorationTheme.copyWith(filled: false, isDense: true),
                ),
                child: SizedBox.expand(child: content),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              ModalBarrier(
                color: Colors.black.withValues(alpha: .42),
                dismissible: !busy,
                onDismiss: () => Get.back(),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(box.maxWidth < 600 ? 12 : 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width,
                      maxHeight: box.maxHeight - 24,
                    ),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class FormColumns extends StatelessWidget {
  const FormColumns({
    super.key,
    required this.children,
    this.mobileColumns = false,
  });
  final bool mobileColumns;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Wrap(
      spacing: 20,
      runSpacing: 16,
      children: children
          .map(
            (child) => SizedBox(
              width: box.maxWidth < (mobileColumns ? 280 : 400)
                  ? box.maxWidth
                  : (box.maxWidth - (children.length - 1) * 20) /
                        children.length,
              child: child,
            ),
          )
          .toList(),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField(this.label, {super.key, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 7),
      child,
    ],
  );
}
