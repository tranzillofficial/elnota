// Arabic (ar) translations for ElNota.
// Keys mirror AppStrings.* constants.
const Map<String, String> arStrings = {
  // ── App ────────────────────────────────────────────────────────────────────
  'app_name': 'النوتة',
  'app_tagline': 'محاسبة بسيطة وموثوقة',

  // ── Navigation ─────────────────────────────────────────────────────────────
  'nav_home': 'الرئيسية',
  'nav_customers': 'العملاء',
  'nav_invoices': 'الفواتير',
  'nav_payments': 'المدفوعات',
  'nav_installments': 'الأقساط',
  'nav_products': 'المنتجات',
  'nav_reports': 'التقارير',
  'nav_settings': 'الإعدادات',

  // ── Common actions ─────────────────────────────────────────────────────────
  'action_add': 'إضافة',
  'action_edit': 'تعديل',
  'action_delete': 'حذف',
  'action_save': 'حفظ',
  'action_cancel': 'إلغاء',
  'action_confirm': 'تأكيد',
  'action_retry': 'إعادة المحاولة',
  'action_close': 'إغلاق',
  'action_search': 'بحث',
  'action_filter': 'تصفية',
  'action_refresh': 'تحديث',
  'action_sync': 'مزامنة',
  'action_back': 'رجوع',
  'action_more': 'المزيد',
  'action_share': 'مشاركة',
  'action_print': 'طباعة',
  'action_export': 'تصدير',

  // ── Status / feedback ──────────────────────────────────────────────────────
  'status_loading': 'جارٍ التحميل…',
  'status_empty': 'لا توجد بيانات',
  'status_error': 'حدث خطأ',
  'status_offline': 'غير متصل بالإنترنت',
  'status_syncing': 'جارٍ المزامنة…',
  'status_synced': 'تمت المزامنة',
  'status_sync_pending': 'في انتظار المزامنة',
  'status_sync_failed': 'فشلت المزامنة',
  'status_saved_locally': 'محفوظ محليًا',

  // ── Customers ──────────────────────────────────────────────────────────────
  'customer_title': 'العملاء',
  'customer_add': 'إضافة عميل',
  'customer_name': 'اسم العميل',
  'customer_phone': 'رقم الهاتف',
  'customer_notes': 'ملاحظات',
  'customer_balance': 'الرصيد',
  'customer_outstanding': 'المديونية',
  'customer_credit': 'رصيد دائن',
  'customer_last_activity': 'آخر نشاط',
  'customer_register_payment': 'تسجيل دفعة',
  'customer_empty': 'لم تُضف عملاء بعد',
  'customer_search_hint': 'ابحث بالاسم أو الهاتف',

  // ── Invoices ───────────────────────────────────────────────────────────────
  'invoice_title': 'الفواتير',
  'invoice_add': 'فاتورة جديدة',
  'invoice_number': 'رقم الفاتورة',
  'invoice_date': 'التاريخ',
  'invoice_due_date': 'تاريخ الاستحقاق',
  'invoice_amount': 'المبلغ',
  'invoice_discount': 'الخصم',
  'invoice_notes': 'ملاحظات',
  'invoice_items': 'البنود',
  'invoice_manual_amount': 'مبلغ يدوي',
  'invoice_status_draft': 'مسودة',
  'invoice_status_posted': 'مرحلة',
  'invoice_status_paid': 'مدفوع',
  'invoice_status_partial': 'مدفوع جزئيًا',
  'invoice_status_overdue': 'متأخر',
  'invoice_empty': 'لا توجد فواتير',

  // ── Payments ───────────────────────────────────────────────────────────────
  'payment_title': 'المدفوعات',
  'payment_add': 'تسجيل دفعة',
  'payment_amount': 'مبلغ الدفعة',
  'payment_date': 'تاريخ الدفعة',
  'payment_notes': 'ملاحظات',
  'payment_confirm_title': 'تأكيد الدفعة',
  'payment_empty': 'لا توجد مدفوعات',

  // ── Installments ───────────────────────────────────────────────────────────
  'installment_title': 'الأقساط',
  'installment_schedule': 'جدول الأقساط',
  'installment_paid': 'مدفوع',
  'installment_remaining': 'المتبقي',
  'installment_next_due': 'موعد القسط القادم',
  'installment_overdue': 'متأخر',
  'installment_empty': 'لا توجد أقساط',

  // ── Products ───────────────────────────────────────────────────────────────
  'product_title': 'المنتجات',
  'product_add': 'إضافة منتج',
  'product_name': 'اسم المنتج',
  'product_price': 'السعر',
  'product_empty': 'لم تُضف منتجات بعد',

  // ── Reports ────────────────────────────────────────────────────────────────
  'report_title': 'التقارير',
  'report_receivables': 'إجمالي المديونيات',
  'report_collected': 'إجمالي المحصل',
  'report_outstanding': 'المديونيات القائمة',

  // ── Settings ───────────────────────────────────────────────────────────────
  'settings_title': 'الإعدادات',
  'settings_account': 'الحساب',
  'settings_business': 'بيانات النشاط',
  'settings_backup_sync': 'النسخ الاحتياطي والمزامنة',
  'settings_appearance': 'المظهر',
  'settings_security': 'الأمان',
  'settings_about': 'حول التطبيق',
  'settings_language': 'اللغة',
  'settings_theme': 'السمة',
  'settings_theme_light': 'فاتح',
  'settings_theme_dark': 'داكن',
  'settings_theme_system': 'حسب النظام',
  'settings_last_sync': 'آخر مزامنة',
  'settings_pending_ops': 'عمليات معلقة',
  'settings_sync_now': 'مزامنة الآن',
  'settings_version': 'الإصدار',

  // ── Auth ────────────────────────────────────────────────────────────────────
  'auth_login': 'تسجيل الدخول',
  'auth_register': 'إنشاء حساب',
  'auth_email': 'البريد الإلكتروني',
  'auth_password': 'كلمة المرور',
  'auth_logout': 'تسجيل الخروج',

  // ── Errors / validation ────────────────────────────────────────────────────
  'error_required': 'هذا الحقل مطلوب',
  'error_invalid_amount': 'مبلغ غير صحيح',
  'error_invalid_phone': 'رقم هاتف غير صحيح',
  'error_invalid_email': 'بريد إلكتروني غير صحيح',
  'error_network': 'تعذّر الاتصال بالخادم',
  'error_unknown': 'حدث خطأ غير متوقع',
  'error_delete_with_balance':
      'لا يمكن حذف عميل لديه رصيد مالي قائم',

  // ── Misc ───────────────────────────────────────────────────────────────────
  'currency_egp': 'ج.م',
  'date_today': 'اليوم',
  'date_yesterday': 'أمس',
  'home_kpi_customers': 'العملاء',
  'home_kpi_receivables': 'المديونيات',
  'home_kpi_collected': 'المحصل',
  'home_recent_activity': 'آخر النشاطات',
  'home_no_activity': 'لا توجد نشاطات حديثة',
};
