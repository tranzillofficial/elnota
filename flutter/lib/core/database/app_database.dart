import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:get/get.dart';
import '../../core/utils/app_constants.dart';
import 'database_impl.dart';

part 'app_database.g.dart';

/// Bare Drift database used as a raw SQL engine.
/// drift_dev/build_runner is absent; the @DriftDatabase annotation is removed
/// so the stub g.dart compiles cleanly. All schema management and queries are
/// in [AppDao] (database_impl.dart) via customSelect / customInsert.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  int get schemaVersion => AppConstants.dbVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => AppDao(this).createTables(),
    onUpgrade: (_, from, to) => AppDao(this).createTables(),
  );

  static QueryExecutor _openConnection(String? name) {
    return driftDatabase(
      name: name ?? AppConstants.dbFileName,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// Factory that also runs PRAGMA setup.
  static Future<AppDatabase> open({String? name}) async {
    final db = AppDatabase(_openConnection(name));
    // WAL mode + foreign keys
    await db.customStatement('PRAGMA journal_mode=WAL');
    await db.customStatement('PRAGMA foreign_keys=ON');
    // Create tables via DAO
    await AppDao(db).createTables();
    return db;
  }
}

/// GetX service — singleton database + DAO access.
class DatabaseService extends GetxService {
  static DatabaseService get to => Get.find<DatabaseService>();

  late AppDatabase db;
  late AppDao dao;

  String? _accountId;
  Future<void> switchAccount(String? userId) async {
    if (_accountId == userId) return;
    await db.close();
    db = await AppDatabase.open(
      name: userId == null
          ? null
          : 'elnota_${userId.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), "")}.db',
    );
    dao = AppDao(db);
    _accountId = userId;
  }

  /// Called from initServices after await.
  void attach(AppDatabase database, {String? accountId}) {
    _accountId = accountId;
    db = database;
    dao = AppDao(database);
  }

  @override
  void onClose() {
    db.close();
    super.onClose();
  }
}
