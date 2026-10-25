import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/money_utils.dart';
import '../models/invoice_model.dart';
import '../repositories/invoice_repository.dart';

class InvoiceDetailView extends StatefulWidget {
  const InvoiceDetailView({super.key});

  @override
  State<InvoiceDetailView> createState() => _InvoiceDetailViewState();
}

class _InvoiceDetailViewState extends State<InvoiceDetailView> {
  late final InvoiceRepository _repo;
  late final String invoiceId;
  InvoiceModel? _invoice;
  List<InvoiceItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    invoiceId = (args?['invoice_id'] ?? args?['id']) as String? ?? '';
    _repo = Get.isRegistered<InvoiceRepository>()
        ? Get.find<InvoiceRepository>()
        : InvoiceRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final inv = await _repo.watchOne(invoiceId).first;
    List<InvoiceItemModel> items = [];
    if (inv != null && !inv.isManualAmount) {
      items = await _repo.getItems(inv.id);
    }
    if (mounted) {
      setState(() {
        _invoice = inv;
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('invoice_title'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final inv = _invoice;
    if (inv == null) {
      return Scaffold(
        appBar: AppBar(title: Text('invoice_title'.tr)),
        body: Center(child: Text('status_empty'.tr)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${'invoice_title'.tr} #${inv.displayNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'action_print'.tr,
            onPressed: () async {
              final bytes = await PdfService.generateInvoicePdf(
                invoice: inv,
                items: _items,
              );
              await PdfService.printDocument(
                bytes,
                name: 'Invoice_${inv.displayNumber}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'action_share'.tr,
            onPressed: () async {
              final bytes = await PdfService.generateInvoicePdf(
                invoice: inv,
                items: _items,
              );
              await PdfService.shareDocument(
                bytes,
                filename: 'Invoice_${inv.displayNumber}.pdf',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'invoice_status_posted'.tr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(inv.status.tr),
                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'invoice_date'.tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${inv.invoiceDate.year}-${inv.invoiceDate.month.toString().padLeft(2, '0')}-${inv.invoiceDate.day.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!inv.isManualAmount && _items.isNotEmpty) ...[
              Text('invoice_items'.tr, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    return ListTile(
                      title: Text(item.description),
                      subtitle: Text(
                        '${item.quantity} × ${MoneyUtils.formatMinor(item.unitPriceMinor)}',
                      ),
                      trailing: Text(
                        MoneyUtils.formatMinor(item.lineTotal),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (inv.notes != null && inv.notes!.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'invoice_notes'.tr,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(inv.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Financial summary
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('invoice_amount'.tr),
                        Text(inv.formattedTotal),
                      ],
                    ),
                    if (inv.discountMinor > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'invoice_discount'.tr,
                            style: const TextStyle(color: Colors.green),
                          ),
                          Text(
                            '- ${MoneyUtils.formatMinor(inv.discountMinor)}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'customer_outstanding'.tr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          inv.formattedNet,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
