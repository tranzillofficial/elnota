import '../../../core/database/database_impl.dart';

class StatementMovement {
  const StatementMovement({
    required this.id,
    required this.reference,
    required this.date,
    required this.label,
    required this.signedMinor,
  });
  final String id;
  final String reference;
  final DateTime date;
  final String label;
  final int signedMinor;
  int get debitMinor => signedMinor > 0 ? signedMinor : 0;
  int get creditMinor => signedMinor < 0 ? -signedMinor : 0;
  factory StatementMovement.fromLedger(LedgerEntryRow row) {
    final credit =
        row.eventType == 'discount' || row.eventType == 'payment_receipt';
    final adjustment = [
      'refund',
      'adjustment',
      'reversal',
    ].contains(row.eventType);
    return StatementMovement(
      id: row.id,
      reference: row.reference ?? row.sourceId,
      date: row.occurredAt,
      label: switch (row.eventType) {
        'invoice_charge' => 'فاتورة بيع',
        'payment_receipt' => 'دفعة نقدية',
        'discount' => 'خصم',
        'refund' => 'استرداد',
        'reversal' => 'عكس قيد',
        _ => 'تسوية حساب',
      },
      signedMinor: credit
          ? -row.amountMinor.abs()
          : adjustment
          ? -row.amountMinor
          : row.amountMinor,
    );
  }
}

class StatementLine {
  const StatementLine(this.movement, this.balanceMinor);
  final StatementMovement movement;
  final int balanceMinor;
}

class AccountStatement {
  AccountStatement({
    required List<StatementMovement> movements,
    required this.from,
    required this.to,
  }) {
    final sorted = [...movements]
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d == 0 ? a.id.compareTo(b.id) : d;
      });
    final end = DateTime(to.year, to.month, to.day + 1);
    var balance = 0;
    for (final movement in sorted) {
      if (movement.date.isBefore(from)) {
        openingMinor += movement.signedMinor;
        balance += movement.signedMinor;
      } else if (movement.date.isBefore(end)) {
        balance += movement.signedMinor;
        debitMinor += movement.debitMinor;
        creditMinor += movement.creditMinor;
        lines.add(StatementLine(movement, balance));
      }
    }
    closingMinor = balance;
  }
  final DateTime from;
  final DateTime to;
  int openingMinor = 0;
  int debitMinor = 0;
  int creditMinor = 0;
  late final int closingMinor;
  final List<StatementLine> lines = [];
}
