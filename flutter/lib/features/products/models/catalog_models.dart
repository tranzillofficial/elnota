class ProductCategory {
  const ProductCategory({required this.id, required this.name});
  final String id, name;
  factory ProductCategory.fromMap(Map<String, dynamic> r) =>
      ProductCategory(id: r['id'] as String, name: r['name'] as String);
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.barcode,
    required this.name,
    required this.priceMinor,
    this.imageWebp,
    this.description,
  });
  final String id, categoryId, categoryName, barcode, name;
  final int priceMinor;
  final String? imageWebp, description;
  factory CatalogProduct.fromMap(Map<String, dynamic> r) => CatalogProduct(
    id: r['id'] as String,
    categoryId: r['category_id'] as String,
    categoryName: r['category_name'] as String,
    barcode: r['barcode'] as String,
    name: r['name'] as String,
    priceMinor: r['price_minor'] as int,
    imageWebp: r['image_webp'] as String?,
    description: r['description'] as String?,
  );
}
