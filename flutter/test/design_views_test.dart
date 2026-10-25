import 'package:elnota/app/views/mobile_more_view.dart';
import 'package:elnota/features/invoices/controllers/invoice_form_controller.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:elnota/core/services/theme_service.dart';
import 'package:elnota/core/services/locale_service.dart';
import 'package:elnota/features/invoices/views/all_invoices_view.dart';
import 'package:elnota/features/invoices/views/invoice_form_view.dart';
import 'package:elnota/features/payments/views/add_payment_view.dart';
import 'package:elnota/features/settings/views/settings_view.dart';
import 'package:elnota/features/customers/views/customer_statement_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:elnota/app/theme/app_theme.dart';
import 'package:elnota/app/views/home_overview_view.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/features/customers/views/customers_list_view.dart';
import 'package:elnota/features/customers/views/customer_detail_view.dart';
import 'package:elnota/features/customers/views/customer_form_view.dart';

class _Dao implements AppDao {
  final date = DateTime(2026, 10, 22);
  @override
  Stream<List<CustomerRow>> watchCustomers({String? search}) => Stream.value(
    List.generate(
      7,
      (i) => CustomerRow(
        id: 'customer$i',
        workspaceId: 'default',
        name: [
          'محمد فؤاد',
          'أحمد محمد',
          'سارة علي',
          'خالد حسن',
          'نور إبراهيم',
          'عمرو السيد',
          'محمود عادل',
        ][i],
        phone: '01012345678',
        notes: 'يفضل التواصل بعد الساعة 5 مساءً',
        version: 0,
        createdAt: date.subtract(Duration(days: i)),
        updatedAt: date,
      ),
    ),
  );
  @override
  Stream<List<InvoiceRow>> watchAllInvoices({String? search, String? status}) =>
      Stream.value(
        List.generate(
          7,
          (i) => InvoiceRow(
            id: 'invoice000$i',
            workspaceId: 'default',
            customerId: 'customer$i',
            status: 'posted',
            totalMinor: 350000,
            discountMinor: 0,
            isManualAmount: true,
            invoiceDate: date,
            version: 0,
            createdAt: date,
            updatedAt: date,
          ),
        ),
      );
  @override
  Stream<List<PaymentRow>> watchAllPayments({String? search}) => Stream.value(
    List.generate(
      7,
      (i) => PaymentRow(
        id: 'payment000$i',
        workspaceId: 'default',
        customerId: 'customer$i',
        amountMinor: 230000,
        paymentDate: date.subtract(Duration(days: i)),
        idempotencyKey: 'key$i',
        version: 0,
        createdAt: date,
        updatedAt: date,
      ),
    ),
  );
  @override
  Stream<CustomerBalance> watchBalance(String customerId) => Stream.value(
    CustomerBalance(
      customerId: customerId,
      totalInvoicedMinor: 350000,
      totalDiscountsMinor: 0,
      totalPaymentsMinor: 230000,
      totalAdjustmentsMinor: 0,
    ),
  );
  @override
  Stream<List<Map<String, dynamic>>> watchInvoiceTerms() => Stream.value([]);
  @override
  Stream<List<LedgerEntryRow>> watchCustomerLedger(String customerId) =>
      Stream.value([
        for (final item in [
          (5, 'invoice_charge', 50000),
          (8, 'payment_receipt', -100000),
          (12, 'invoice_charge', 120000),
          (15, 'payment_receipt', -50000),
          (18, 'invoice_charge', 80000),
          (19, 'payment_receipt', -50000),
          (21, 'payment_receipt', -30000),
          (22, 'invoice_charge', 100000),
        ])
          LedgerEntryRow(
            id: '${item.$1}',
            workspaceId: 'default',
            customerId: customerId,
            sourceId: 'REF-${item.$1}',
            eventType: item.$2,
            amountMinor: item.$3,
            occurredAt: DateTime(2026, 10, item.$1),
            createdAt: DateTime(2026, 10, item.$1),
          ),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Database extends DatabaseService {
  _Database() {
    dao = _Dao();
  }
  @override
  void onClose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;
  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync('elnota-ui-tests-');
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
  setUp(() {
    Get.testMode = true;
    Get.put<DatabaseService>(_Database());
    Get.put(ThemeService());
    Get.put(LocaleService());
  });
  tearDown(() {
    Get.reset();
  });
  for (final width in [320.0, 390.0, 1586.0]) {
    for (final screen in [
      'dashboard',
      'more',
      'customers',
      'detail',
      'invoices',
      'statement',
      'invoice-form',
      'payment-form',
      'settings',
      'customer-form',
    ]) {
      testWidgets('$screen RTL at $width pixels', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          GetMaterialApp(
            theme: AppTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: screen == 'more'
                  ? MobileMoreView(onSelect: (_) {})
                  : screen == 'dashboard'
                  ? const HomeOverviewView()
                  : screen == 'invoices'
                  ? const AllInvoicesView()
                  : screen == 'customer-form'
                  ? const CustomerFormView()
                  : screen == 'settings'
                  ? const SettingsView()
                  : const CustomersListView(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if ([
          'detail',
          'statement',
          'invoice-form',
          'payment-form',
        ].contains(screen)) {
          Get.to(
            () => Directionality(
              textDirection: TextDirection.rtl,
              child: screen == 'detail'
                  ? const CustomerDetailView()
                  : screen == 'statement'
                  ? const CustomerStatementView()
                  : screen == 'invoice-form'
                  ? const InvoiceFormView()
                  : const AddPaymentView(),
            ),
            arguments: {'id': 'customer0', 'customer_id': 'customer0'},
            opaque: false,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        if (screen == 'customers') {
          expect(find.text('محمد فؤاد'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'سارة');
          await tester.pumpAndSettle();
          expect(find.text('سارة علي'), findsOneWidget);
          expect(find.text('محمد فؤاد'), findsNothing);
        }
        if (screen == 'invoice-form' && width < 600) {
          await tester.tap(find.text('إضافة صنف'));
          await tester.pumpAndSettle();
          final form = Get.find<InvoiceFormController>();
          expect(form.items, hasLength(1));
          await tester.tap(find.byTooltip('زيادة الكمية'));
          await tester.pumpAndSettle();
          expect(form.items.single.quantity, 2);
          await tester.tap(find.byTooltip('حذف البند'));
          await tester.pumpAndSettle();
          expect(form.items, isEmpty);
          await tester.tap(find.text('مبلغ فقط'));
          await tester.pumpAndSettle();
          expect(find.text('قيمة الفاتورة'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        if (screen == 'detail') {
          expect(find.text('تسجيل دفعة'), findsOneWidget);
          expect(find.text('3,500.00 ج.م'), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
