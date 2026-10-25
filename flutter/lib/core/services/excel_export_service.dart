import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/money_utils.dart';
import '../../features/customers/models/customer_model.dart';
import '../../features/invoices/models/invoice_model.dart';

class ExcelExportService {
  ExcelExportService._();

  /// Generates an Excel spreadsheet containing customers and invoices data.
  static List<int>? generateAccountingWorkbook({
    required List<CustomerModel> customers,
    required List<InvoiceModel> invoices,
  }) {
    final excel = Excel.createExcel();

    // ── Sheet 1: Customers ──────────────────────────────────────────────────
    final sheetCustomers = excel['Customers'];
    sheetCustomers.appendRow([
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Notes'),
      TextCellValue('Created Date'),
    ]);

    for (final c in customers) {
      sheetCustomers.appendRow([
        TextCellValue(c.id),
        TextCellValue(c.name),
        TextCellValue(c.phone ?? ''),
        TextCellValue(c.notes ?? ''),
        TextCellValue(
          '${c.createdAt.year}-${c.createdAt.month}-${c.createdAt.day}',
        ),
      ]);
    }

    // ── Sheet 2: Invoices ───────────────────────────────────────────────────
    final sheetInvoices = excel['Invoices'];
    sheetInvoices.appendRow([
      TextCellValue('Invoice ID'),
      TextCellValue('Customer ID'),
      TextCellValue('Status'),
      TextCellValue('Total (EGP)'),
      TextCellValue('Discount (EGP)'),
      TextCellValue('Net (EGP)'),
      TextCellValue('Date'),
      TextCellValue('Notes'),
    ]);

    for (final inv in invoices) {
      sheetInvoices.appendRow([
        TextCellValue(inv.id),
        TextCellValue(inv.customerId),
        TextCellValue(inv.status),
        TextCellValue(MoneyUtils.formatMinorNoSymbol(inv.totalMinor)),
        TextCellValue(MoneyUtils.formatMinorNoSymbol(inv.discountMinor)),
        TextCellValue(MoneyUtils.formatMinorNoSymbol(inv.netMinor)),
        TextCellValue(
          '${inv.invoiceDate.year}-${inv.invoiceDate.month}-${inv.invoiceDate.day}',
        ),
        TextCellValue(inv.notes ?? ''),
      ]);
    }

    // Remove default sheet
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.save();
  }

  /// Exports and shares the workbook via share_plus.
  static Future<void> exportAndShareWorkbook({
    required List<CustomerModel> customers,
    required List<InvoiceModel> invoices,
    String fileName = 'ElNota_Export.xlsx',
  }) async {
    final bytes = generateAccountingWorkbook(
      customers: customers,
      invoices: invoices,
    );
    if (bytes == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'ElNota Accounting Export',
      ),
    );
  }
}
