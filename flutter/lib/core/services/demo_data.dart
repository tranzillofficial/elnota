import '../database/database_impl.dart';

/// Fictional records in the dedicated demo DB; never seeded into an account DB.
abstract class DemoData {
  static Future<void> seed(AppDao dao) async {
    if ((await dao.watchCustomers().first).isNotEmpty) return;
    final now = DateTime.now();
    final people = [
      'محمد فؤاد',
      'أحمد محمد',
      'سارة علي',
      'خالد حسن',
      'نور إبراهيم',
      'عمرو السيد',
      'محمود عادل',
    ];
    for (var i = 0; i < people.length; i++) {
      final id = await dao.createCustomer(
        name: people[i],
        phone: '0100000000$i',
        notes: 'عميل تجريبي — البيانات للتجربة فقط',
      );
      await dao.createInvoiceWithTerms(
        customerId: id,
        totalMinor: [300000, 200000, 180000, 90000, 125000, 230000, 160000][i],
        discountMinor: 0,
        isManualAmount: true,
        items: [],
        method: i % 3 == 0 ? 'installments' : 'credit',
        upfrontMinor: i % 3 == 0 ? 60000 : 0,
        months: 6,
        firstDueDate: DateTime(now.year, now.month, now.day - 10),
        invoiceDate: DateTime(now.year, now.month, now.day - i - 15),
        notes: 'فاتورة تجريبية',
      );
    }
    await dao.saveCategory(name: 'أجهزة');
    await dao.saveCategory(name: 'مستلزمات');
    final categories = await dao.watchCategories().first;
    final devices = categories.firstWhere((c) => c.name == 'أجهزة').id;
    final supplies = categories.firstWhere((c) => c.name == 'مستلزمات').id;
    await dao.saveProduct(
      categoryId: devices,
      barcode: 'DEMO-001',
      name: 'طابعة حرارية',
      priceMinor: 200000,
      description: 'منتج تجريبي لتجربة الكتالوج',
    );
    await dao.saveProduct(
      categoryId: supplies,
      barcode: 'DEMO-002',
      name: 'رول ورق حراري',
      priceMinor: 10000,
    );
    await dao.saveProduct(
      categoryId: devices,
      barcode: 'DEMO-003',
      name: 'قارئ باركود',
      priceMinor: 85000,
    );
  }
}
