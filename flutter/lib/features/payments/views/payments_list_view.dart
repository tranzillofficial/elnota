import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/widgets/app_widgets.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';

class PaymentsListView extends StatelessWidget {
  const PaymentsListView({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = Get.isRegistered<PaymentRepository>()
        ? Get.find<PaymentRepository>()
        : PaymentRepository();

    return StreamBuilder<List<PaymentModel>>(
      stream: repo.watchByCustomer(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return AppEmptyWidget(
            icon: Icons.payments_outlined,
            message: 'payment_empty'.tr,
            actionLabel: 'payment_add'.tr,
            onAction: () => Get.toNamed(
              AppRoutes.paymentCreate,
              arguments: {'customer_id': customerId},
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: payments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = payments[index];
            final d = p.paymentDate;
            final formattedDate =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.arrow_downward, color: Colors.green),
                ),
                title: Text(
                  p.formattedAmount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                subtitle: p.notes != null && p.notes!.isNotEmpty
                    ? Text('${p.notes}\n$formattedDate')
                    : Text(formattedDate),
                isThreeLine: p.notes != null && p.notes!.isNotEmpty,
                trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }
}
