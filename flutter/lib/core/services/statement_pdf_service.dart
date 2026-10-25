import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/customers/models/account_statement.dart';
import '../utils/money_utils.dart';

class StatementPdfService {
  static Future<Uint8List> generate({
    required String name,
    String? phone,
    required AccountStatement statement,
  }) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo.ttf'));
    final pdf = pw.Document();
    String money(int amount) => MoneyUtils.formatMinorNoSymbol(amount);
    String date(DateTime d) => '${d.day}/${d.month}/${d.year}';
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        build: (context) => [
          pw.Text(
            'كشف حساب العميل',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('$name  ${phone ?? ''}'),
          pw.Text('الفترة: ${date(statement.from)} إلى ${date(statement.to)}'),
          pw.SizedBox(height: 16),
          pw.Text('رصيد أول الفترة: ${money(statement.openingMinor)} ج.م'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['الرصيد', 'دائن', 'مدين', 'المرجع', 'البيان', 'التاريخ'],
            data: statement.lines
                .map(
                  (l) => [
                    money(l.balanceMinor),
                    l.movement.creditMinor == 0
                        ? '—'
                        : money(l.movement.creditMinor),
                    l.movement.debitMinor == 0
                        ? '—'
                        : money(l.movement.debitMinor),
                    l.movement.reference,
                    l.movement.label,
                    date(l.movement.date),
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'إجمالي المدين: ${money(statement.debitMinor)} ج.م    إجمالي الدائن: ${money(statement.creditMinor)} ج.م',
          ),
          pw.Text(
            'رصيد آخر الفترة: ${money(statement.closingMinor)} ج.م',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          if (statement.closingMinor < 0) pw.Text('رصيد لصالح العميل'),
        ],
      ),
    );
    return pdf.save();
  }
}
