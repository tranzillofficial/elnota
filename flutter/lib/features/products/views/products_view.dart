import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/account_access_service.dart';
import '../../../core/services/product_image_service.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/design_widgets.dart';
import '../controllers/catalog_controller.dart';
import '../models/catalog_models.dart';
import '../repositories/catalog_repository.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key, this.controller});
  final CatalogController? controller;
  @override
  Widget build(BuildContext context) => GetBuilder<CatalogController>(
    init: controller ?? CatalogController(),
    global: false,
    builder: (c) {
      if (!c.allowed) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: designGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'المنتجات',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'متاحة مع اشتراك كلاود نشط، أو بتفعيل خاص من الإدارة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => AccountAccessService.to.refreshAccess(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث صلاحيات الحساب'),
                ),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 16,
                  spacing: 20,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المنتجات',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'منتجاتك وأقسامك، منظمة في مكان واحد',
                          style: TextStyle(color: designMuted),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              Get.to(() => _CategoriesView(controller: c)),
                          icon: const Icon(Icons.category_outlined),
                          label: const Text('إدارة الأقسام'),
                        ),
                        FilledButton.icon(
                          onPressed: () => Get.to(
                            () => ProductFormView(
                              categories: List.of(c.categories),
                            ),
                            opaque: false,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('منتج جديد'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _Stat(
                      'إجمالي المنتجات',
                      c.products.length,
                      Icons.inventory_2_outlined,
                    ),
                    _Stat(
                      'الأقسام',
                      c.categories.length,
                      Icons.category_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DesignPanel(
                  title: 'قائمة المنتجات',
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: c.search,
                          decoration: const InputDecoration(
                            hintText: 'ابحث بالباركود أو اسم المنتج أو القسم',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('الكل'),
                                selected: c.categoryId == null,
                                onSelected: (_) => c.selectCategory(null),
                              ),
                              for (final cat in c.categories)
                                ChoiceChip(
                                  label: Text(cat.name),
                                  selected: c.categoryId == cat.id,
                                  onSelected: (_) => c.selectCategory(cat.id),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (c.error != null)
                          Text(
                            c.error!,
                            style: const TextStyle(color: Colors.red),
                          )
                        else if (c.loading)
                          const CircularProgressIndicator()
                        else if (c.filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(35),
                            child: Text(
                              c.products.isEmpty
                                  ? 'ابدأ بإضافة قسم ثم أول منتج.'
                                  : 'لا توجد منتجات تطابق البحث.',
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns = box.maxWidth < 520
                                  ? 1
                                  : box.maxWidth < 900
                                  ? 2
                                  : 3;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  for (final p in c.filtered)
                                    SizedBox(
                                      width:
                                          (box.maxWidth - (columns - 1) * 14) /
                                          columns,
                                      child: _ProductCard(
                                        product: p,
                                        onEdit: () => Get.to(
                                          () => ProductFormView(
                                            categories: List.of(c.categories),
                                            product: p,
                                          ),
                                          opaque: false,
                                        ),
                                        onArchive: () async {
                                          if (await _confirm(
                                            'أرشفة المنتج ${p.name}؟',
                                          )) {
                                            try {
                                              await c.repository.archive(p.id);
                                              AppToast.success(
                                                'تمت أرشفة المنتج',
                                              );
                                            } catch (_) {
                                              AppToast.error(
                                                'تعذر أرشفة المنتج',
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            '${c.filtered.length} منتج',
                            style: const TextStyle(
                              color: designMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'البيانات محفوظة على الجهاز؛ المزامنة السحابية تتطلب تفعيل بيئة الكلاود الجديدة.',
                  style: TextStyle(fontSize: 12, color: designMuted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: designBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: designGreen),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: designMuted)),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onArchive,
  });
  final CatalogProduct product;
  final VoidCallback onEdit, onArchive;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: designBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          color: const Color(0xFFF4F8F6),
          child: product.imageWebp == null
              ? const Icon(
                  Icons.inventory_2_outlined,
                  size: 45,
                  color: designGreen,
                )
              : Image.memory(
                  base64Decode(product.imageWebp!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, e, s) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onArchive(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('تعديل المنتج'),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('أرشفة المنتج'),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                product.categoryName,
                style: const TextStyle(color: designMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                product.barcode,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: designMuted, fontSize: 12),
              ),
              if (product.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    product.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                designMoney(product.priceMinor),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: designGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(String message) async =>
    await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تأكيد الأرشفة'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    ) ??
    false;

class _CategoriesView extends StatelessWidget {
  const _CategoriesView({required this.controller});
  final CatalogController controller;
  Future<void> _edit(ProductCategory? category) async {
    final field = TextEditingController(text: category?.name);
    String? error;
    bool busy = false;
    await Get.dialog(
      StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(category == null ? 'قسم جديد' : 'تعديل القسم'),
          content: TextField(
            controller: field,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'اسم القسم',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Get.back(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (field.text.trim().isEmpty) {
                        set(() => error = 'اسم القسم مطلوب');
                        return;
                      }
                      set(() => busy = true);
                      try {
                        await controller.repository.saveCategory(
                          id: category?.id,
                          name: field.text,
                        );
                        Get.back();
                      } catch (_) {
                        set(() {
                          busy = false;
                          error = 'تعذر الحفظ؛ قد يوجد قسم بنفس الاسم';
                        });
                      }
                    },
              child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    field.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أقسام المنتجات')),
    body: GetBuilder<CatalogController>(
      init: controller,
      global: false,
      autoRemove: false,
      builder: (c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('قسم جديد'),
            ),
          ),
          const SizedBox(height: 20),
          if (c.categories.isEmpty) const Text('أضف أول قسم لتنظيم منتجاتك.'),
          for (final cat in c.categories)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: designBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.category_outlined,
                  color: designGreen,
                ),
                title: Text(cat.name),
                subtitle: Text(
                  '${c.products.where((p) => p.categoryId == cat.id).length} منتج',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'تعديل القسم',
                      onPressed: () => _edit(cat),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'أرشفة القسم',
                      onPressed: () async {
                        if (await _confirm('أرشفة القسم ${cat.name}؟')) {
                          try {
                            await c.repository.archive(cat.id, category: true);
                          } catch (_) {
                            AppToast.error(
                              'انقل أو أرشف منتجات القسم قبل أرشفته',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.archive_outlined),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ProductFormView extends StatefulWidget {
  const ProductFormView({super.key, required this.categories, this.product});
  final List<ProductCategory> categories;
  final CatalogProduct? product;
  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name),
      barcode = TextEditingController(text: widget.product?.barcode),
      price = TextEditingController(
        text: widget.product == null
            ? ''
            : MoneyUtils.minorToDisplay(widget.product!.priceMinor),
      ),
      description = TextEditingController(text: widget.product?.description);
  late String? category = widget.product?.categoryId,
      image = widget.product?.imageWebp;
  bool saving = false, compressing = false;
  String? error;
  @override
  void dispose() {
    for (final c in [name, barcode, price, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      setState(() => compressing = true);
      final length = await files.single.length();
      if (length != null && length > 10 * 1024 * 1024) {
        throw const FormatException('اختر صورة أصغر من 10 ميجابايت');
      }
      final bytes = await ProductImageService.compress(
        await files.single.readAsBytes(),
      );
      if (mounted) setState(() => image = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر قراءة الصورة أو ضغطها؛ جرّب صورة أصغر');
      }
    } finally {
      if (mounted) setState(() => compressing = false);
    }
  }

  Future<void> save() async {
    if (saving || compressing || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await CatalogRepository().saveProduct(
        id: widget.product?.id,
        categoryId: category!,
        barcode: barcode.text,
        name: name.text,
        priceMinor: MoneyUtils.parseToMinor(price.text)!,
        description: description.text.trim(),
        imageWebp: image,
      );
      Get.back();
      AppToast.success('تم حفظ المنتج على هذا الجهاز');
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'تعذر الحفظ؛ تأكد من صلاحية الحساب وعدم تكرار الباركود',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountingFormFrame(
    title: widget.product == null ? 'منتج جديد' : 'تعديل المنتج',
    width: 640,
    busy: saving || compressing,
    footer: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: saving || compressing ? null : save,
            icon: const Icon(Icons.check),
            label: Text(saving ? 'جارٍ الحفظ…' : 'حفظ المنتج'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: saving || compressing ? null : () => Get.back(),
          child: const Text('إلغاء'),
        ),
      ],
    ),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'بيانات المنتج',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          LabeledField(
            'اسم المنتج',
            child: TextFormField(
              controller: name,
              maxLength: 160,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'اكتب اسم المنتج' : null,
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            'القسم',
            child: DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              items: widget.categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => category = v,
              validator: (v) => v == null ? 'أضف قسمًا ثم اختاره للمنتج' : null,
              decoration: InputDecoration(
                hintText: widget.categories.isEmpty
                    ? 'أنشئ قسمًا من إدارة الأقسام أولًا'
                    : 'اختر القسم',
              ),
            ),
          ),
          const SizedBox(height: 14),
          FormColumns(
            children: [
              LabeledField(
                'الباركود',
                child: TextFormField(
                  controller: barcode,
                  maxLength: 128,
                  textDirection: TextDirection.ltr,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الباركود مطلوب' : null,
                ),
              ),
              LabeledField(
                'السعر (ج.م)',
                child: TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final amount = MoneyUtils.parseToMinor(v ?? '');
                    return amount == null || amount < 0
                        ? 'اكتب سعرًا صحيحًا'
                        : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            'صورة المنتج (اختياري)',
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(image!),
                      width: 85,
                      height: 85,
                      fit: BoxFit.cover,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: compressing ? null : pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(compressing ? 'جارٍ ضغط الصورة…' : 'اختيار صورة'),
                ),
                if (image != null)
                  TextButton(
                    onPressed: () => setState(() => image = null),
                    child: const Text('إزالة الصورة'),
                  ),
              ],
            ),
          ),
          const Text(
            'تتحول الصورة إلى WebP، بأبعاد حتى 960 بكسل وحجم حتى 512 كيلوبايت.',
            style: TextStyle(fontSize: 11, color: designMuted),
          ),
          const SizedBox(height: 14),
          LabeledField(
            'الوصف (اختياري)',
            child: TextFormField(
              controller: description,
              maxLines: 3,
              maxLength: 2000,
            ),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
  );
}
