import '../../../core/database/app_database.dart';
import '../../../core/database/database_impl.dart';
import '../../../core/services/account_access_service.dart';
import '../models/catalog_models.dart';

class CatalogRepository {
  AppDao get _dao => DatabaseService.to.dao;
  void _requireAccess() {
    if (!AccountAccessService.to.catalogEnabled) {
      throw StateError('المنتجات متاحة للكلاود أو بتفعيل من الإدارة');
    }
  }

  Stream<List<ProductCategory>> watchCategories() {
    _requireAccess();
    return _dao.watchCategories();
  }

  Stream<List<CatalogProduct>> watchProducts() {
    _requireAccess();
    return _dao.watchProducts();
  }

  Future<void> saveCategory({String? id, required String name}) {
    _requireAccess();
    return _dao.saveCategory(id: id, name: name);
  }

  Future<void> saveProduct({
    String? id,
    required String categoryId,
    required String barcode,
    required String name,
    required int priceMinor,
    String? imageWebp,
    String? description,
  }) {
    _requireAccess();
    return _dao.saveProduct(
      id: id,
      categoryId: categoryId,
      barcode: barcode,
      name: name,
      priceMinor: priceMinor,
      imageWebp: imageWebp,
      description: description,
    );
  }

  Future<void> archive(String id, {bool category = false}) {
    _requireAccess();
    return _dao.archiveCatalog(id, category: category);
  }
}
