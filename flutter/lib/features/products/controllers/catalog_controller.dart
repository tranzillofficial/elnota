import 'dart:async';
import 'package:get/get.dart';
import '../../../core/services/account_access_service.dart';
import '../models/catalog_models.dart';
import '../repositories/catalog_repository.dart';

class CatalogController extends GetxController {
  CatalogController({CatalogRepository? repository})
    : repository = repository ?? CatalogRepository();
  final CatalogRepository repository;
  List<CatalogProduct> products = [];
  List<ProductCategory> categories = [];
  String query = '';
  String? categoryId, error;
  bool loading = true;
  final _subs = <StreamSubscription<dynamic>>[];
  Worker? _access;
  bool get allowed => AccountAccessService.to.catalogEnabled;
  List<CatalogProduct> get filtered => products
      .where(
        (p) =>
            (categoryId == null || p.categoryId == categoryId) &&
            [
              p.barcode,
              p.name,
              p.categoryName,
            ].any((s) => s.toLowerCase().contains(query.trim().toLowerCase())),
      )
      .toList();
  @override
  void onInit() {
    super.onInit();
    _access = ever(AccountAccessService.to.access, (_) => _bind());
    _bind();
  }

  void _bind() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    products = [];
    categories = [];
    loading = allowed;
    error = null;
    if (allowed) {
      _subs.add(
        repository.watchProducts().listen(
          (r) {
            products = r;
            loading = false;
            update();
          },
          onError: (_) {
            error = 'تعذر تحميل المنتجات';
            loading = false;
            update();
          },
        ),
      );
      _subs.add(
        repository.watchCategories().listen(
          (r) {
            categories = r;
            update();
          },
          onError: (_) {
            error = 'تعذر تحميل الأقسام';
            loading = false;
            update();
          },
        ),
      );
    }
    update();
  }

  void search(String value) {
    query = value;
    update();
  }

  void selectCategory(String? id) {
    categoryId = id;
    update();
  }

  @override
  void onClose() {
    _access?.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}
