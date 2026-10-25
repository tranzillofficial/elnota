import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/utils/money_utils.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/features/customers/models/customer_model.dart';
import 'package:elnota/features/invoices/models/invoice_model.dart';
import 'package:elnota/features/payments/models/payment_model.dart';

void main() {
  group('MoneyUtils Tests', () {
    test('formats minor units accurately without floating point imprecision', () {
      expect(MoneyUtils.minorToDisplay(100), '1.00');
      expect(MoneyUtils.minorToDisplay(1050), '10.50');
      expect(MoneyUtils.minorToDisplay(5), '0.05');
      expect(MoneyUtils.minorToDisplay(0), '0.00');
      expect(MoneyUtils.minorToDisplay(-1250), '-12.50');

      expect(MoneyUtils.formatMinor(15000), '150.00 ج.م');
      expect(MoneyUtils.formatMinor(250, symbol: 'USD'), '2.50 USD');
    });

    test('parses display string into minor integer units safely', () {
      expect(MoneyUtils.parseToMinor('150'), 15000);
      expect(MoneyUtils.parseToMinor('150.50'), 15050);
      expect(MoneyUtils.parseToMinor('0.99'), 99);
      expect(MoneyUtils.parseToMinor('0.05'), 5);
      expect(MoneyUtils.parseToMinor('   25.75  '), 2575);
      expect(MoneyUtils.parseToMinor(''), isNull);
      expect(MoneyUtils.parseToMinor('abc'), isNull);
      expect(MoneyUtils.parseToMinor('-50.00'), -5000);
    });
  });

  group('Invoice Financial Rules', () {
    test('calculates net amount after discounts correctly', () {
      final inv = InvoiceModel(
        id: 'inv_1',
        customerId: 'cust_1',
        status: 'posted',
        totalMinor: 50000, // 500.00
        discountMinor: 5000, // 50.00
        isManualAmount: true,
        invoiceDate: DateTime.now(),
      );

      expect(inv.netMinor, 45000);
      expect(inv.formattedNet, '450.00 ج.م');
      expect(inv.formattedTotal, '500.00 ج.م');
      expect(inv.isPosted, isTrue);
      expect(inv.isDraft, isFalse);
    });

    test('calculates invoice item line totals correctly', () {
      const item = InvoiceItemModel(
        id: 'item_1',
        description: 'Product A',
        quantity: 3,
        unitPriceMinor: 10000, // 100.00 each = 300.00
        discountMinor: 2000, // 20.00 discount
      );

      expect(item.lineTotal, 28000); // 280.00
    });
  });

  group('Customer Balance & Ledger Accounting Formula', () {
    test('computes outstanding balance from ledger totals correctly', () {
      // Invoiced: 1,000 (100,000 minor)
      // Discounts: 100 (10,000 minor)
      // Payments: 400 (40,000 minor)
      // Adjustments: 0
      // Net expected: 100,000 - 10,000 - 40,000 = 50,000 minor (500)
      final balance = CustomerBalance(
        customerId: 'cust_1',
        totalInvoicedMinor: 100000,
        totalDiscountsMinor: 10000,
        totalPaymentsMinor: 40000,
        totalAdjustmentsMinor: 0,
      );

      expect(balance.outstandingMinor, 50000);

      final summary = CustomerBalanceSummary.fromRow(balance);
      expect(summary.hasCredit, isFalse);
      expect(summary.isZero, isFalse);
      expect(summary.formattedOutstanding, '500.00 ج.م');
      expect(summary.formattedInvoiced, '1,000.00 ج.م');
      expect(summary.formattedPayments, '400.00 ج.م');
    });

    test('handles credit balance when customer overpays', () {
      // Invoiced: 500 (50,000 minor)
      // Payments: 600 (60,000 minor)
      // Outstanding = 50,000 - 60,000 = -10,000 (customer has credit of 100)
      final balance = CustomerBalance(
        customerId: 'cust_2',
        totalInvoicedMinor: 50000,
        totalDiscountsMinor: 0,
        totalPaymentsMinor: 60000,
        totalAdjustmentsMinor: 0,
      );

      expect(balance.outstandingMinor, -10000);

      final summary = CustomerBalanceSummary.fromRow(balance);
      expect(summary.hasCredit, isTrue);
      expect(summary.isZero, isFalse);
    });

    test('handles zero balance when fully settled', () {
      final balance = CustomerBalance(
        customerId: 'cust_3',
        totalInvoicedMinor: 50000,
        totalDiscountsMinor: 0,
        totalPaymentsMinor: 50000,
        totalAdjustmentsMinor: 0,
      );

      expect(balance.outstandingMinor, 0);

      final summary = CustomerBalanceSummary.fromRow(balance);
      expect(summary.hasCredit, isFalse);
      expect(summary.isZero, isTrue);
    });
  });

  group('Payment Domain Model & Idempotency Key', () {
    test('payment model maps correctly and provides minor formatting', () {
      final p = PaymentModel(
        id: 'pmt_1',
        customerId: 'cust_1',
        amountMinor: 25000,
        paymentDate: DateTime(2026, 10, 20),
        idempotencyKey: 'idemp_key_12345',
        notes: 'Cash receipt',
      );

      expect(p.amountMinor, 25000);
      expect(p.formattedAmount, '250.00 ج.م');
      expect(p.idempotencyKey, 'idemp_key_12345');
      expect(p.notes, 'Cash receipt');
    });
  });
}
