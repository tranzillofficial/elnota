part of 'database_impl.dart';

extension CatalogDao on AppDao {
  Future<void> createCatalogTables() async {
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS product_categories (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER)''',
    );
    await _db.customStatement(
      '''CREATE UNIQUE INDEX IF NOT EXISTS category_name_unique ON product_categories(workspace_id, name COLLATE NOCASE) WHERE deleted_at IS NULL''',
    );
    await _db.customStatement('''CREATE TABLE IF NOT EXISTS catalog_products (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, category_id TEXT NOT NULL,
      barcode TEXT NOT NULL CHECK(length(trim(barcode)) > 0), name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      price_minor INTEGER NOT NULL CHECK(price_minor >= 0), image_webp TEXT, description TEXT,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
      FOREIGN KEY(category_id) REFERENCES product_categories(id))''');
    await _db.customStatement(
      '''CREATE UNIQUE INDEX IF NOT EXISTS catalog_barcode_unique ON catalog_products(workspace_id, barcode COLLATE NOCASE) WHERE deleted_at IS NULL''',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS catalog_category_idx ON catalog_products(workspace_id, category_id)',
    );
  }

  Stream<List<ProductCategory>> watchCategories() => _db
      .customSelect(
        'SELECT * FROM product_categories WHERE workspace_id = ? AND deleted_at IS NULL ORDER BY name COLLATE NOCASE',
        variables: [Variable.withString(_wsId)],
      )
      .watchLocal()
      .map((rows) => rows.map((r) => ProductCategory.fromMap(r.data)).toList());
  Stream<List<CatalogProduct>> watchProducts() => _db
      .customSelect(
        '''SELECT p.*, c.name AS category_name FROM catalog_products p JOIN product_categories c ON c.id=p.category_id AND c.workspace_id=p.workspace_id WHERE p.workspace_id=? AND p.deleted_at IS NULL AND c.deleted_at IS NULL ORDER BY p.updated_at DESC, p.id''',
        variables: [Variable.withString(_wsId)],
      )
      .watchLocal()
      .map((rows) => rows.map((r) => CatalogProduct.fromMap(r.data)).toList());

  Future<void> saveCategory({String? id, required String name}) async {
    name = name.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('اسم القسم مطلوب وبحد أقصى 100 حرف');
    }
    final key = id ?? _uuid.v4(), now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      if (id == null) {
        await _db.customStatement(
          'INSERT INTO product_categories(id,workspace_id,name,created_at,updated_at) VALUES(?,?,?,?,?)',
          [key, _wsId, name, now, now],
        );
      } else {
        final changed = await _db.customUpdate(
          'UPDATE product_categories SET name=?,updated_at=?,version=version+1 WHERE id=? AND workspace_id=? AND deleted_at IS NULL',
          variables: [
            Variable.withString(name),
            Variable.withInt(now),
            Variable.withString(key),
            Variable.withString(_wsId),
          ],
        );
        if (changed != 1) throw StateError('القسم غير متاح');
      }
      await _enqueueOutbox(
        entityType: 'product_category',
        entityId: key,
        operationType: id == null ? 'create' : 'update',
        payload: {'id': key, 'name': name},
      );
    });
    LocalQueryChanges.notify();
  }

  Future<void> saveProduct({
    String? id,
    required String categoryId,
    required String barcode,
    required String name,
    required int priceMinor,
    String? imageWebp,
    String? description,
  }) async {
    barcode = barcode.trim();
    name = name.trim();
    if (barcode.isEmpty ||
        barcode.length > 128 ||
        name.isEmpty ||
        name.length > 160 ||
        priceMinor < 0 ||
        priceMinor > 9007199254740991) {
      throw ArgumentError('راجع اسم المنتج والباركود والسعر');
    }
    if ((description?.length ?? 0) > 2000) {
      throw ArgumentError('الوصف أطول من 2000 حرف');
    }
    if (imageWebp != null) {
      final bytes = base64Decode(imageWebp);
      if (bytes.length > 512 * 1024 ||
          bytes.length < 12 ||
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WEBP') {
        throw ArgumentError('الصورة يجب أن تكون WebP مضغوطة');
      }
    }
    final key = id ?? _uuid.v4(), now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final category = await _db
          .customSelect(
            'SELECT id FROM product_categories WHERE id=? AND workspace_id=? AND deleted_at IS NULL',
            variables: [
              Variable.withString(categoryId),
              Variable.withString(_wsId),
            ],
          )
          .getSingleOrNull();
      if (category == null) throw StateError('اختر قسمًا متاحًا');
      if (id == null) {
        await _db.customStatement(
          '''INSERT INTO catalog_products(id,workspace_id,category_id,barcode,name,price_minor,image_webp,description,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)''',
          [
            key,
            _wsId,
            categoryId,
            barcode,
            name,
            priceMinor,
            imageWebp,
            description,
            now,
            now,
          ],
        );
      } else {
        final changed = await _db.customUpdate(
          '''UPDATE catalog_products SET category_id=?,barcode=?,name=?,price_minor=?,image_webp=?,description=?,updated_at=?,version=version+1 WHERE id=? AND workspace_id=? AND deleted_at IS NULL''',
          variables: [
            Variable.withString(categoryId),
            Variable.withString(barcode),
            Variable.withString(name),
            Variable.withInt(priceMinor),
            Variable<String>(imageWebp),
            Variable<String>(description),
            Variable.withInt(now),
            Variable.withString(key),
            Variable.withString(_wsId),
          ],
        );
        if (changed != 1) throw StateError('المنتج غير متاح');
      }
      await _enqueueOutbox(
        entityType: 'catalog_product',
        entityId: key,
        operationType: id == null ? 'create' : 'update',
        payload: {
          'id': key,
          'category_id': categoryId,
          'barcode': barcode,
          'name': name,
          'price_minor': priceMinor,
          'image_webp': imageWebp,
          'description': description,
        },
      );
    });
    LocalQueryChanges.notify();
  }

  Future<void> archiveCatalog(String id, {bool category = false}) async {
    final table = category ? 'product_categories' : 'catalog_products';
    await _db.transaction(() async {
      if (category) {
        final used = await _db
            .customSelect(
              'SELECT id FROM catalog_products WHERE category_id=? AND workspace_id=? AND deleted_at IS NULL LIMIT 1',
              variables: [Variable.withString(id), Variable.withString(_wsId)],
            )
            .get();
        if (used.isNotEmpty) {
          throw StateError('انقل أو أرشف منتجات القسم أولًا');
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await _db.customUpdate(
        'UPDATE $table SET deleted_at=?,updated_at=?,version=version+1 WHERE id=? AND workspace_id=? AND deleted_at IS NULL',
        variables: [
          Variable.withInt(now),
          Variable.withInt(now),
          Variable.withString(id),
          Variable.withString(_wsId),
        ],
      );
      if (changed != 1) throw StateError('العنصر غير متاح');
      await _enqueueOutbox(
        entityType: category ? 'product_category' : 'catalog_product',
        entityId: id,
        operationType: 'delete',
        payload: {'id': id, 'deleted_at': now},
      );
    });
    LocalQueryChanges.notify();
  }
}
