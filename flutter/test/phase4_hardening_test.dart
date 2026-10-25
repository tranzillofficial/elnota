import 'package:flutter/services.dart';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/services/pdf_service.dart';
import 'package:elnota/core/services/excel_export_service.dart';
import 'package:elnota/features/customers/models/customer_model.dart';
import 'package:elnota/features/invoices/models/invoice_model.dart';
import 'package:elnota/features/payments/models/payment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;
  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync('elnota-pdf-tests-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => storageDirectory.path,
        );
    await GetStorage('GetStorage', storageDirectory.path).initStorage;
  });
  tearDownAll(() {
    try {
      storageDirectory.deleteSync(recursive: true);
    } on FileSystemException {
      /* GetStorage retains a Windows file handle until the test isolate exits. */
    }
  });
  group('PdfService Generation Tests', () {
    test('generates valid invoice PDF document with PDF header', () async {
      final inv = InvoiceModel(
        id: 'inv_abc_12345',
        customerId: 'cust_101',
        status: 'posted',
        totalMinor: 150000,
        discountMinor: 5000,
        isManualAmount: false,
        invoiceDate: DateTime(2026, 10, 20),
        notes: 'Thank you for your business',
      );

      const item1 = InvoiceItemModel(
        id: 'item_1',
        description: 'Item 1',
        quantity: 2,
        unitPriceMinor: 50000,
        discountMinor: 0,
      );

      final bytes = await PdfService.generateInvoicePdf(
        invoice: inv,
        customerName: 'Ahmad Mustafa',
        items: [item1],
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      // Validate PDF signature: starts with %PDF-
      final signature = String.fromCharCodes(bytes.take(5));
      expect(signature, '%PDF-');
    });

    test('generates valid customer account statement PDF document', () async {
      final customer = CustomerModel(
        id: 'cust_1',
        workspaceId: 'ws_1',
        name: 'Mahmoud Ali',
        phone: '01099887766',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 20),
      );

      const balance = CustomerBalanceSummary(
        customerId: 'cust_1',
        totalInvoicedMinor: 100000,
        totalDiscountsMinor: 5000,
        totalPaymentsMinor: 40000,
        outstandingMinor: 55000,
      );

      final inv = InvoiceModel(
        id: 'inv_1',
        customerId: 'cust_1',
        status: 'posted',
        totalMinor: 100000,
        discountMinor: 5000,
        isManualAmount: true,
        invoiceDate: DateTime(2026, 10, 10),
      );

      final pmt = PaymentModel(
        id: 'pmt_1',
        customerId: 'cust_1',
        amountMinor: 40000,
        paymentDate: DateTime(2026, 10, 15),
        idempotencyKey: 'idemp_test_1',
      );

      final bytes = await PdfService.generateCustomerStatementPdf(
        customer: customer,
        balance: balance,
        invoices: [inv],
        payments: [pmt],
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      final signature = String.fromCharCodes(bytes.take(5));
      expect(signature, '%PDF-');
    });
  });

  group('ExcelExportService Tests', () {
    test(
      'generates valid Excel workbook containing customers and invoices',
      () {
        final customer = CustomerModel(
          id: 'cust_2',
          workspaceId: 'ws_1',
          name: 'Tarek Zaki',
          phone: '01122334455',
          notes: 'VIP client',
          createdAt: DateTime(2026, 10, 5),
          updatedAt: DateTime(2026, 10, 5),
        );

        final inv = InvoiceModel(
          id: 'inv_2',
          customerId: 'cust_2',
          status: 'posted',
          totalMinor: 25000,
          discountMinor: 0,
          isManualAmount: true,
          invoiceDate: DateTime(2026, 10, 18),
        );

        final bytes = ExcelExportService.generateAccountingWorkbook(
          customers: [customer],
          invoices: [inv],
        );

        expect(bytes, isNotNull);
        expect(bytes!.isNotEmpty, isTrue);
        // XLSX is a ZIP archive; starts with PK header
        final header = String.fromCharCodes(bytes.take(2));
        expect(header, 'PK');
      },
    );
  });
}
