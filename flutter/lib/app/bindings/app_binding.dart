import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/database/app_database.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/sync/services/sync_service.dart';
import '../../features/auth/services/auth_service.dart';
import '../../core/services/account_access_service.dart';
import '../../core/services/daily_backup_service.dart';
import '../../core/utils/app_runtime.dart';
import '../../core/services/demo_data.dart';

/// Root application binding.
/// Core services are registered in [initServices] before [runApp].
class AppBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ThemeService>()) {
      Get.put<ThemeService>(ThemeService(), permanent: true);
    }
    if (!Get.isRegistered<LocaleService>()) {
      Get.put<LocaleService>(LocaleService(), permanent: true);
    }
    if (!Get.isRegistered<DatabaseService>()) {
      Get.put<DatabaseService>(DatabaseService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    if (!Get.isRegistered<SupabaseService>()) {
      Get.put<SupabaseService>(SupabaseService(), permanent: true);
    }
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<SyncService>()) {
      Get.put<SyncService>(SyncService(), permanent: true);
    }
    if (!Get.isRegistered<AccountAccessService>()) {
      Get.put(AccountAccessService(), permanent: true);
    }
    if (!Get.isRegistered<DailyBackupService>()) {
      Get.put(DailyBackupService(), permanent: true);
    }
  }
}

/// Initialises services before [runApp].
/// Call this once from [main] before the app widget tree is built.
Future<void> initServices() async {
  await GetStorage.init();
  Get.put<ThemeService>(ThemeService(), permanent: true);
  Get.put<LocaleService>(LocaleService(), permanent: true);
  final supabase = Get.put<SupabaseService>(SupabaseService(), permanent: true);
  if (!AppRuntime.demo) {
    await supabase.ensureInitialized();
  }
  final userId = supabase.client?.auth.currentUser?.id;
  final dbSvc = Get.put<DatabaseService>(DatabaseService(), permanent: true);
  final db = await AppDatabase.open(
    name: AppRuntime.demo
        ? AppRuntime.demoDatabase
        : userId == null
        ? null
        : 'elnota_$userId.db',
  );
  dbSvc.attach(db, accountId: userId);
  if (AppRuntime.demo) {
    await db.transaction(() => DemoData.seed(dbSvc.dao));
    final access = AccountAccessService(automaticallyRefresh: false);
    access.access.value = const AccountAccess(
      active: true,
      catalogOverride: true,
    );
    Get.put(access, permanent: true);
  }
  Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
  Get.put<AuthService>(AuthService(), permanent: true);
  Get.put<SyncService>(SyncService(), permanent: true);
}
