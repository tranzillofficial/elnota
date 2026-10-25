import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/database/app_database.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/core/services/demo_data.dart';
import 'package:elnota/core/services/supabase_service.dart';
import 'package:elnota/core/services/daily_backup_service.dart';
import 'package:elnota/core/sync/services/sync_service.dart';
import 'package:elnota/core/utils/app_runtime.dart';
import 'package:elnota/core/utils/app_constants.dart';
import 'package:elnota/features/admin/repositories/admin_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('demo uses an isolated DB and hard-disables all cloud writes', () {
    expect(AppRuntime.demoDatabase, isNot(AppConstants.dbFileName));
    expect(SyncService.ledgerCloudEnabled, false);
    expect(DailyBackupService.backendEnabled, false);
    expect(AdminRepository.writesEnabled, false);
    expect(SupabaseService().client, isNull);
  }, skip: !AppRuntime.demo);
  test(
    'fictional demo seeding is atomic and repeatable without duplicates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = AppDao(db);
      addTearDown(db.close);
      await dao.createTables();
      await db.transaction(() => DemoData.seed(dao));
      expect(await dao.watchCustomers().first, hasLength(7));
      expect(await dao.watchAllInvoices().first, hasLength(7));
      expect(await dao.watchProducts().first, hasLength(3));
      await db.transaction(() => DemoData.seed(dao));
      expect(await dao.watchCustomers().first, hasLength(7));
    },
  );
}
