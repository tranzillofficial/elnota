/// Named route constants for the entire app.
/// All navigation uses these identifiers — no string literals in features.
library;

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String admin = '/admin';
  static const String settings = '/settings';

  // ── Auth ───────────────────────────────────────────────────────────────────
  static const String deviceLogin = '/auth/device-login';
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // ── Customers ──────────────────────────────────────────────────────────────
  static const String customers = '/customers';
  static const String customerStatement = '/customers/statement';
  static const String customerDetail = '/customers/detail';
  static const String customerCreate = '/customers/create';

  // ── Invoices ───────────────────────────────────────────────────────────────
  static const String invoices = '/invoices';
  static const String invoiceDetail = '/invoices/detail';
  static const String invoiceCreate = '/invoices/create';

  // ── Payments ───────────────────────────────────────────────────────────────
  static const String payments = '/payments';
  static const String paymentCreate = '/payments/create';

  // ── Installments ───────────────────────────────────────────────────────────
  static const String installments = '/installments';

  // ── Products ───────────────────────────────────────────────────────────────
  static const String products = '/products';

  // ── Reports ────────────────────────────────────────────────────────────────
  static const String reports = '/reports';
}
