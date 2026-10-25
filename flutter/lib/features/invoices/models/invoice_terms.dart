import 'invoice_model.dart';

class InvoiceTerms {
  const InvoiceTerms({
    required this.invoiceId,
    required this.customerId,
    required this.method,
    required this.upfrontMinor,
    required this.months,
    required this.firstDueDate,
  });
  final String invoiceId;
  final String customerId;
  final String method;
  final int upfrontMinor;
  final int months;
  final DateTime firstDueDate;
  factory InvoiceTerms.fromMap(Map<String, dynamic> row) => InvoiceTerms(
    invoiceId: row['invoice_id'] as String,
    customerId: row['customer_id'] as String,
    method: row['method'] as String,
    upfrontMinor: row['upfront_minor'] as int,
    months: row['months'] as int,
    firstDueDate: DateTime.fromMillisecondsSinceEpoch(
      row['first_due_date'] as int,
    ),
  );
}

class ScheduledDue {
  const ScheduledDue({
    required this.invoiceId,
    required this.customerId,
    required this.date,
    required this.amountMinor,
    required this.remainingMinor,
    required this.index,
  });
  final String invoiceId;
  final String customerId;
  final DateTime date;
  final int amountMinor;
  final int remainingMinor;
  final int index;
  bool overdueAt(DateTime now) =>
      remainingMinor > 0 &&
      date.isBefore(DateTime(now.year, now.month, now.day));
}

/// Calendar-month arithmetic preserves the original anchor day, clamping month ends.
DateTime installmentDate(DateTime first, int offset) {
  final month = DateTime(first.year, first.month + offset);
  final last = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, first.day > last ? last : first.day);
}

/// Integer-only split; the last installment carries the remaining minor units.
List<int> installmentAmounts(int principal, int months) {
  if (principal < 0 || months < 1 || months > 120) {
    throw ArgumentError('Invalid installment plan');
  }
  return List.generate(
    months,
    (i) => principal ~/ months + (i == months - 1 ? principal % months : 0),
  );
}

/// Customer-wide credits are projected FIFO over all dated obligations, including
/// older legacy credit invoices. No second debt or mutable paid flags are created.
List<ScheduledDue> allocateCustomerDues({
  required List<InvoiceModel> invoices,
  required List<InvoiceTerms> terms,
  required int outstandingMinor,
}) {
  final posted = invoices.where((i) => i.isPosted).toList();
  final byId = {for (final t in terms) t.invoiceId: t};
  final obligations = <ScheduledDue>[];
  var upfront = 0;
  var charges = 0;
  for (final invoice in posted) {
    charges += invoice.netMinor;
    final t = byId[invoice.id];
    final advance = t?.upfrontMinor ?? 0;
    upfront += advance;
    final principal = invoice.netMinor - advance;
    if (principal <= 0) continue;
    final amounts = installmentAmounts(
      principal,
      t?.method == 'installments' ? t!.months : 1,
    );
    for (var i = 0; i < amounts.length; i++) {
      obligations.add(
        ScheduledDue(
          invoiceId: invoice.id,
          customerId: invoice.customerId,
          date: installmentDate(
            t?.firstDueDate ?? invoice.dueDate ?? invoice.invoiceDate,
            i,
          ),
          amountMinor: amounts[i],
          remainingMinor: amounts[i],
          index: i + 1,
        ),
      );
    }
  }
  obligations.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.invoiceId.compareTo(b.invoiceId);
  });
  var available = charges - outstandingMinor - upfront;
  if (available < 0) available = 0;
  return obligations.map((due) {
    final applied = available < due.amountMinor ? available : due.amountMinor;
    available -= applied;
    return ScheduledDue(
      invoiceId: due.invoiceId,
      customerId: due.customerId,
      date: due.date,
      amountMinor: due.amountMinor,
      remainingMinor: due.amountMinor - applied,
      index: due.index,
    );
  }).toList();
}
