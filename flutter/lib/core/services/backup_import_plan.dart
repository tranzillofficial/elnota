import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'product_image_service.dart';

/// Pure conversion. No database or network writes are allowed during preview.
class BackupImportPlan {
  BackupImportPlan(this.source, this.tables, this.warnings, this.profile);
  final Map<String, dynamic> source;
  final Map<String, List<Map<String, dynamic>>> tables;
  final List<String> warnings;
  final Map<String, dynamic> profile;
  String get identity =>
      const Uuid().v5(Namespace.url.value, jsonEncode(source));
  int count(String table) => tables[table]?.length ?? 0;
  int get balanceMinor => tables['ledger_entries']!.fold(
    0,
    (n, r) => n + (r['amount_minor'] as int),
  );
  static const columns = <String, List<String>>{
    'customers': [
      'id',
      'workspace_id',
      'name',
      'phone',
      'notes',
      'version',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    'product_categories': [
      'id',
      'workspace_id',
      'name',
      'created_at',
      'updated_at',
      'version',
      'deleted_at',
    ],
    'catalog_products': [
      'id',
      'workspace_id',
      'category_id',
      'barcode',
      'name',
      'price_minor',
      'image_webp',
      'description',
      'created_at',
      'updated_at',
      'version',
      'deleted_at',
    ],
    'invoices': [
      'id',
      'workspace_id',
      'customer_id',
      'invoice_number',
      'status',
      'total_minor',
      'discount_minor',
      'notes',
      'is_manual_amount',
      'invoice_date',
      'due_date',
      'version',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    'invoice_items': [
      'id',
      'invoice_id',
      'product_id',
      'description',
      'quantity',
      'unit_price_minor',
      'discount_minor',
      'created_at',
    ],
    'payments': [
      'id',
      'workspace_id',
      'customer_id',
      'amount_minor',
      'notes',
      'payment_date',
      'idempotency_key',
      'version',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    'invoice_terms': [
      'invoice_id',
      'workspace_id',
      'customer_id',
      'method',
      'upfront_minor',
      'months',
      'first_due_date',
    ],
    'ledger_entries': [
      'id',
      'workspace_id',
      'customer_id',
      'source_id',
      'event_type',
      'amount_minor',
      'notes',
      'occurred_at',
      'created_at',
    ],
  };

  factory BackupImportPlan.parse(String content, {String? accountId}) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ملف النسخة غير صالح');
    }
    if (decoded['owner_id'] != null && decoded['owner_id'] != accountId) {
      throw const FormatException('هذه النسخة تخص حسابًا آخر');
    }
    final data = Map<String, dynamic>.from(
      decoded['data'] is Map ? decoded['data'] as Map : decoded,
    );
    final tables = {
      for (final name in columns.keys) name: <Map<String, dynamic>>[],
    };
    if (data['schemaVersion'] == 1) return _legacy(decoded, data, tables);
    if (data['schema_version'] != 3) {
      throw const FormatException('إصدار النسخة غير مدعوم');
    }
    for (final table in columns.keys) {
      if (data[table] is! List) throw FormatException('جدول مفقود: $table');
      for (final value in data[table] as List) {
        if (value is! Map) throw const FormatException('سجل غير صالح');
        final row = Map<String, dynamic>.from(value);
        if (row.keys.any((k) => !columns[table]!.contains(k))) {
          throw FormatException('حقول غير مدعومة في $table');
        }
        if (table != 'invoice_items') row['workspace_id'] = 'default';
        tables[table]!.add(row);
      }
    }
    final plan = BackupImportPlan(decoded, tables, [
      'الاستيراد متاح لدفتر فارغ فقط، ولا يستبدل دفترًا قائمًا.',
    ], Map<String, dynamic>.from(decoded['business_profile'] as Map? ?? {}));
    plan.validate();
    return plan;
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> d,
    String name, {
    bool optional = false,
  }) {
    final value = d[name];
    if (optional && value == null) return [];
    if (value is! List) throw FormatException('بيانات $name غير صالحة');
    return value.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  static String _text(Map<String, dynamic> r, String key) {
    if (r[key] is! String) throw FormatException('حقل $key غير صالح');
    return r[key] as String;
  }

  static num _number(dynamic n) {
    if (n is! num || !n.isFinite || n < 0 || n > 90071992547400) {
      throw const FormatException('مبلغ أو كمية غير صالحة');
    }
    return n;
  }

  static int _minor(dynamic n) => (_number(n) * 100).round();
  static int _date(String s) {
    final d = DateTime.tryParse(s);
    if (d == null) {
      throw const FormatException('تاريخ غير صالح؛ لم يتم تغيير أي بيانات');
    }
    return d.millisecondsSinceEpoch;
  }

  static BackupImportPlan _legacy(
    Map<String, dynamic> original,
    Map<String, dynamic> data,
    Map<String, List<Map<String, dynamic>>> t,
  ) {
    final now = _date(_text(data, 'updatedAt'));
    Map<String, dynamic> base(String id) => {
      'id': id,
      'workspace_id': 'default',
      'version': 0,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    };
    String stable(String kind, String id) =>
        const Uuid().v5(Namespace.url.value, 'elnota-legacy/$kind/$id');
    final customers = _rows(data, 'customers'),
        invoices = _rows(data, 'invoices');
    final products = _rows(data, 'products');
    final warnings = <String>[
      'يتم الحفاظ على إجماليات الفواتير القديمة؛ البنود ذات الكميات الكسرية تُعرض كبند مرحّل مع تفاصيل الكمية الأصلية.',
      'حُفظ الملف الأصلي كاملًا داخل أرشيف الاستيراد. لا يتم رفعه إلى الكلاود.',
      'النسخة القديمة لا تحدد مالك الملف؛ تأكد أنها تخص الحساب المفتوح.',
    ];
    for (final c in customers) {
      final notes = [
        _text(c, 'notes'),
        if (_text(c, 'address').isNotEmpty) 'العنوان: ${c['address']}',
      ].where((s) => s.isNotEmpty).join('\n');
      t['customers']!.add({
        ...base(_text(c, 'id')),
        'name': _text(c, 'name'),
        'phone': _text(c, 'phone'),
        'notes': notes,
      });
    }
    final cats = <String, String>{};
    for (final p in products) {
      final category = (p['category'] as String?)?.trim();
      final name = category == null || category.isEmpty ? 'بدون قسم' : category;
      final categoryKey = name.toLowerCase();
      final categoryId = cats.putIfAbsent(categoryKey, () {
        final id = stable('category', categoryKey);
        t['product_categories']!.add({...base(id), 'name': name});
        return id;
      });
      final barcode = _text(p, 'barcode');
      t['catalog_products']!.add({
        ...base(_text(p, 'id')),
        'category_id': categoryId,
        'name': _text(p, 'name'),
        'barcode': barcode.isEmpty ? 'LEGACY-${p['id']}' : barcode,
        'price_minor': _minor(p['price']),
        'image_webp': null,
        'description': null,
        'deleted_at': p['archived'] == true ? now : null,
      });
    }
    if (products.any((p) => p['image'] != null)) {
      warnings.add(
        'صور المنتجات القديمة محفوظة في الأرشيف الأصلي؛ تحويلها إلى WebP لم يكتمل بعد.',
      );
    }
    void receipt(
      Map<String, dynamic> p,
      String customer,
      String key,
      int amount,
    ) {
      if (amount <= 0) {
        throw const FormatException('دفعة أقل من قرش أو غير صالحة');
      }
      final id = stable('receipt', key), date = _date(_text(p, 'date'));
      t['payments']!.add({
        ...base(id),
        'customer_id': customer,
        'amount_minor': amount,
        'notes': _text(p, 'note'),
        'payment_date': date,
        'idempotency_key': id,
      });
      t['ledger_entries']!.add({
        'id': stable('ledger', id),
        'workspace_id': 'default',
        'customer_id': customer,
        'source_id': id,
        'event_type': 'payment_receipt',
        'amount_minor': -amount,
        'notes': _text(p, 'note'),
        'occurred_at': date,
        'created_at': now,
      });
    }

    for (final inv in invoices) {
      final id = _text(inv, 'id'), customer = _text(inv, 'customerId');
      final date = _date(_text(inv, 'date')), voided = inv['voided'] == true;
      final lines = _rows(inv, 'lines'), payments = _rows(inv, 'payments');
      if (lines.isEmpty) throw const FormatException('فاتورة بلا بنود');
      final amounts = lines
          .map((l) => _number(l['price']) * _number(l['quantity']))
          .toList();
      final total = (amounts.fold<num>(0, (a, b) => a + b) * 100).round();
      final paid =
          (payments.fold<num>(0, (a, p) => a + _number(p['amount'])) * 100)
              .round();
      if (paid > total) throw const FormatException('المدفوع أكبر من الفاتورة');
      t['invoices']!.add({
        ...base(id),
        'customer_id': customer,
        'invoice_number': _text(inv, 'number'),
        'status': voided ? 'voided' : 'posted',
        'total_minor': total,
        'discount_minor': 0,
        'notes': _text(inv, 'notes'),
        'is_manual_amount': inv['entryMode'] == 'amount' ? 1 : 0,
        'invoice_date': date,
        'due_date': _text(inv, 'dueDate').isEmpty
            ? null
            : _date(inv['dueDate'] as String),
      });
      var allocated = 0;
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i],
            amount = i == lines.length - 1
                ? total - allocated
                : (amounts[i] * 100).round();
        allocated += amount;
        if (amount < 0 || _number(l['quantity']) <= 0) {
          throw const FormatException('راجع تقريب بنود الفاتورة');
        }
        final quantity = _number(l['quantity']);
        final unit = _minor(l['price']);
        final exact = quantity is int && quantity * unit == amount;
        t['invoice_items']!.add({
          'id': stable('item', '$id/$i'),
          'invoice_id': id,
          'product_id': null,
          'description': exact
              ? _text(l, 'name')
              : '${_text(l, 'name')} (${l['quantity']} × ${l['price']} ج.م — بند مرحّل)',
          'quantity': exact ? quantity : 1,
          'unit_price_minor': exact ? unit : amount,
          'discount_minor': 0,
          'created_at': now,
        });
      }
      if (!voided) {
        t['ledger_entries']!.add({
          'id': stable('charge', id),
          'workspace_id': 'default',
          'customer_id': customer,
          'source_id': id,
          'event_type': 'invoice_charge',
          'amount_minor': total,
          'notes': inv['notes'],
          'occurred_at': date,
          'created_at': now,
        });
        var received = 0;
        for (var i = 0; i < payments.length; i++) {
          final amount = i == payments.length - 1
              ? paid - received
              : _minor(payments[i]['amount']);
          received += amount;
          receipt(
            payments[i],
            customer,
            '$id/${_text(payments[i], 'id')}',
            amount,
          );
        }
        final method = inv['method'];
        if (!['cash', 'credit', 'installment'].contains(method)) {
          throw const FormatException('طريقة دفع غير مدعومة');
        }
        final plan = inv['installmentPlan'];
        if (plan is Map) {
          final months = plan['months'];
          if (months is! int || months < 1 || months > 120) {
            throw const FormatException('خطة أقساط غير صالحة');
          }
          final upfront = total - _minor(plan['financedAmount']);
          if (upfront < 0 || upfront > paid) {
            throw const FormatException('مقدمة خطة الأقساط لا تطابق الدفعات');
          }
          t['invoice_terms']!.add({
            'invoice_id': id,
            'workspace_id': 'default',
            'customer_id': customer,
            'method': 'installments',
            'upfront_minor': upfront,
            'months': months,
            'first_due_date': _date(plan['firstDueDate'] as String),
          });
        }
      }
    }
    final accountPayments = _rows(data, 'customerPayments', optional: true);
    // Old documents round account receipts as one subtotal. Reject sub-piaster
    // values rather than silently changing customer totals.
    for (final p in accountPayments) {
      if ((_number(p['amount']) * 100 - _minor(p['amount'])).abs() > 0.000001) {
        throw const FormatException('دفعة قديمة تحتاج مراجعة تقريب يدوي');
      }
      receipt(
        p,
        _text(p, 'customerId'),
        'customer/${_text(p, 'id')}',
        _minor(p['amount']),
      );
    }
    final settings = Map<String, dynamic>.from(data['settings'] as Map);
    if (!['جنيه', 'ج.م', 'EGP'].contains(settings['currency'])) {
      throw const FormatException('عملة النسخة ليست جنيهًا مصريًا');
    }
    final result = BackupImportPlan(original, t, warnings, {
      'name': settings['businessName'],
      'phone': settings['phone'],
      'address': settings['address'],
    });
    result.validate();
    return result;
  }

  Future<void> prepareLegacyImages() async {
    final data = source['data'] is Map ? source['data'] as Map : source;
    if (data['schemaVersion'] != 1) return;
    final originals = {for (final p in data['products'] as List) p['id']: p};
    for (final row in tables['catalog_products']!) {
      final image = originals[row['id']]?['image'];
      if (image is String && image.isNotEmpty) {
        try {
          final bytes = base64Decode(image.substring(image.indexOf(',') + 1));
          row['image_webp'] = base64Encode(
            await ProductImageService.compress(bytes),
          );
        } catch (_) {
          throw const FormatException(
            'تعذر تحويل صورة منتج قديم. الملف الأصلي لم يتغير ولم يُستورد أي سجل.',
          );
        }
      }
    }
    warnings.removeWhere((w) => w.contains('تحويلها إلى WebP لم يكتمل'));
  }

  void validate() {
    final ids = <String, Set<dynamic>>{};
    for (final name in columns.keys) {
      final rows = tables[name]!;
      final pk = name == 'invoice_terms' ? 'invoice_id' : 'id';
      final keys = rows.map((r) => r[pk]).toSet();
      if (keys.length != rows.length ||
          keys.any((k) => k is! String || (k).isEmpty)) {
        throw FormatException('معرفات مكررة أو ناقصة: $name');
      }
      ids[name] = keys;
      for (final r in rows) {
        if (r.keys.any((k) => !columns[name]!.contains(k))) {
          throw const FormatException('حقول غير مدعومة');
        }
        for (final e in r.entries) {
          if (e.key.endsWith('_minor') &&
              (e.value is! int || (e.value as int).abs() > 9007199254740991)) {
            throw const FormatException('مبلغ غير صحيح');
          }
        }
      }
    }
    for (final name in [
      'invoices',
      'payments',
      'ledger_entries',
      'invoice_terms',
    ]) {
      for (final r in tables[name]!) {
        if (!ids['customers']!.contains(r['customer_id'])) {
          throw const FormatException('عميل مفقود');
        }
      }
    }
    for (final r in tables['invoice_items']!) {
      if (!ids['invoices']!.contains(r['invoice_id']) ||
          r['quantity'] is! int ||
          (r['quantity'] as int) <= 0) {
        throw const FormatException('بند فاتورة غير صالح');
      }
    }
    for (final r in tables['catalog_products']!) {
      if (!ids['product_categories']!.contains(r['category_id'])) {
        throw const FormatException('قسم منتج مفقود');
      }
    }
    for (final i in tables['invoices']!) {
      if (!['posted', 'draft', 'voided'].contains(i['status'])) {
        throw const FormatException('حالة فاتورة غير صالحة');
      }
      final lines = tables['invoice_items']!.where(
        (r) => r['invoice_id'] == i['id'],
      );
      final amount = lines.fold<int>(
        0,
        (n, r) =>
            n +
            (r['quantity'] as int) * (r['unit_price_minor'] as int) -
            (r['discount_minor'] as int),
      );
      if (amount != i['total_minor']) {
        throw const FormatException('إجمالي البنود لا يطابق الفاتورة');
      }
      final charges = tables['ledger_entries']!
          .where(
            (r) =>
                r['source_id'] == i['id'] &&
                r['event_type'] == 'invoice_charge',
          )
          .toList();
      if (i['status'] == 'posted' &&
          (charges.length != 1 ||
              charges.single['amount_minor'] !=
                  (i['total_minor'] as int) - (i['discount_minor'] as int) ||
              charges.single['customer_id'] != i['customer_id'])) {
        throw const FormatException('رصيد الفاتورة لا يطابق دفتر الحساب');
      }
    }
    for (final p in tables['payments']!) {
      final receipts = tables['ledger_entries']!
          .where(
            (r) =>
                r['source_id'] == p['id'] &&
                r['event_type'] == 'payment_receipt',
          )
          .toList();
      if (p['amount_minor'] is! int ||
          (p['amount_minor'] as int) <= 0 ||
          receipts.length != 1 ||
          receipts.single['amount_minor'] != -(p['amount_minor'] as int) ||
          receipts.single['customer_id'] != p['customer_id']) {
        throw const FormatException('دفعة لا تطابق دفتر الحساب');
      }
    }
    for (final e in tables['ledger_entries']!) {
      if (e['event_type'] == 'invoice_charge' &&
          !ids['invoices']!.contains(e['source_id'])) {
        throw const FormatException('قيد فاتورة بلا مصدر');
      }
      if (e['event_type'] == 'payment_receipt' &&
          !ids['payments']!.contains(e['source_id'])) {
        throw const FormatException('قيد دفعة بلا مصدر');
      }
    }
  }
}
