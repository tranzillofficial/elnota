import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/widgets/app_widgets.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';

/// Workspace-wide payments list view.
/// Shows all recorded payments with real-time updates and search.
class AllPaymentsView extends StatefulWidget {
  const AllPaymentsView({super.key});

  @override
  State<AllPaymentsView> createState() => _AllPaymentsViewState();
}

class _AllPaymentsViewState extends State<AllPaymentsView> {
  final _searchCtrl = TextEditingController();
  final _searchQuery = ''.obs;

  late final PaymentRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<PaymentRepository>()
        ? Get.find<PaymentRepository>()
        : Get.put(PaymentRepository());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('nav_payments'.tr),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.paymentCreate),
        icon: const Icon(Icons.add),
        label: Text('payment_add'.tr),
      ),
      body: Column(
        children: [
          // ─── Search Bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن دفعة أو عميل...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchQuery.value = '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _searchQuery.value = v.trim(),
            ),
          ),

          // ─── Payments Stream ──────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              final search = _searchQuery.value;

              return StreamBuilder<List<PaymentModel>>(
                stream: _repo.watchAll(search: search),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }

                  final payments = snapshot.data ?? [];
                  if (payments.isEmpty) {
                    return AppEmptyWidget(
                      icon: Icons.payments_outlined,
                      message: 'payment_empty'.tr,
                      actionLabel: 'payment_add'.tr,
                      onAction: () => Get.toNamed(AppRoutes.paymentCreate),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: payments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = payments[index];
                      final d = p.paymentDate;
                      final formattedDate =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            p.customerName ?? 'عميل',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$formattedDate${p.notes != null ? ' • ${p.notes}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Text(
                            p.formattedAmount,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          onTap: () => Get.toNamed(
                            AppRoutes.customerDetail,
                            arguments: {'id': p.customerId},
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
