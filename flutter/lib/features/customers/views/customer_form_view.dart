import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/accounting_form_frame.dart';
import '../../../core/widgets/design_widgets.dart';
import '../repositories/customer_repository.dart';

/// Create or edit a customer.
class CustomerFormView extends StatefulWidget {
  const CustomerFormView({super.key});

  @override
  State<CustomerFormView> createState() => _CustomerFormViewState();
}

class _CustomerFormViewState extends State<CustomerFormView> {
  late final CustomerRepository _repo;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = false;
  String? _loadError;
  String? _editId;
  bool get _isEdit => _editId != null;

  @override
  void initState() {
    super.initState();
    _repo = CustomerRepository();
    final args = Get.arguments as Map<String, dynamic>?;
    _editId = args?['id'] as String?;
    if (_isEdit) {
      _loading = true;
      // Pre-fill from passed args or stream (simplest: re-read from repo).
      _loadForEdit();
    }
  }

  Future<void> _loadForEdit() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final c = await _repo.watchOne(_editId!).first;
      if (!mounted) return;
      if (c == null) {
        setState(() => _loadError = 'هذا العميل غير متاح للتعديل');
        return;
      }
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone ?? '';
      _notesCtrl.text = c.notes ?? '';
    } catch (_) {
      if (mounted) setState(() => _loadError = 'تعذر تحميل بيانات العميل');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _loadError != null ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.update(
          id: _editId!,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        showSuccessSnack('customer_updated'.tr);
      } else {
        await _repo.create(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        showSuccessSnack('customer_created'.tr);
      }
      Get.back();
    } catch (e) {
      showErrorSnack('${'error_generic'.tr}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountingFormFrame(
    title: _isEdit ? 'تعديل بيانات العميل' : 'عميل جديد',
    width: 580,
    busy: _saving,
    footer: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving || _loading || _loadError != null ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ بيانات العميل'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _saving ? null : () => Get.back(),
          child: const Text('إلغاء'),
        ),
      ],
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Text(_loadError!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: _loadForEdit,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: designGreen.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  color: designGreen,
                  size: 30,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حساب عميل منظم من أول تعامل',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'أضف بياناته الأساسية، وابدأ تسجيل فواتيره ودفعاته.',
                        style: TextStyle(color: designMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LabeledField(
            'اسم العميل',
            child: TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              maxLength: 160,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'اكتب الاسم بالكامل',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'اسم العميل مطلوب' : null,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            'رقم الهاتف (اختياري)',
            child: TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 30,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '01012345678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            'ملاحظات (اختياري)',
            child: TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'معلومة تساعدك في التعامل مع العميل',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الرصيد يتحدد من الفواتير والدفعات المسجلة على الحساب.',
            style: TextStyle(color: designMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
