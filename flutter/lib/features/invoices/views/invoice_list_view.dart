import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/invoice_list_controller.dart';

class InvoiceListView extends StatelessWidget {
  const InvoiceListView({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = 'invoices_$customerId';
    final ctrl = Get.put(
      InvoiceListController(customerId: customerId),
      tag: tag,
    );

    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.invoices.isEmpty) {
        return AppEmptyWidget(
          icon: Icons.receipt_long_outlined,
          message: 'invoice_empty'.tr,
          actionLabel: 'invoice_add'.tr,
          onAction: () => Get.toNamed(
            AppRoutes.invoiceCreate,
            arguments: {'customer_id': customerId},
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: ctrl.invoices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final inv = ctrl.invoices[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.receipt_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                '${'invoice_title'.tr} #${inv.displayNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${inv.invoiceDate.year}-${inv.invoiceDate.month.toString().padLeft(2, '0')}-${inv.invoiceDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inv.formattedNet,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    inv.status.tr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              onTap: () => Get.toNamed(
                AppRoutes.invoiceDetail,
                arguments: {'invoice_id': inv.id},
              ),
            ),
          );
        },
      );
    });
  }
}
