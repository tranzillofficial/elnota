import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_runtime.dart';

abstract interface class AdminAccountControls {
  Future<void> manageAccount(String userId, String operation);
  Future<void> manageCloud(String userId, String plan);
}

abstract interface class AdminGateway {
  Future<bool> isAdmin();
  Future<List<Map<String, dynamic>>> accounts(int page);
  Future<List<Map<String, dynamic>>> requests(int page);
  Future<void> review(String requestId, bool approve);
  Future<void> setPrinting(String userId, bool enabled);
  Future<void> setCatalog(String userId, bool enabled);
}

class AdminRepository implements AdminGateway, AdminAccountControls {
  static const writesEnabled =
      !AppRuntime.demo &&
      bool.fromEnvironment('ENABLE_ADMIN_WRITES', defaultValue: false);
  SupabaseClient? get _client =>
      Get.isRegistered<SupabaseService>() ? SupabaseService.to.client : null;
  @override
  Future<bool> isAdmin() async {
    final client = _client;
    if (client?.auth.currentSession == null) return false;
    return await client!.rpc('elnota_is_admin') == true;
  }

  Future<SupabaseClient> _authorized({bool write = false}) async {
    if (write && !writesEnabled) {
      throw StateError('الإدارة للقراءة فقط في هذا الإصدار');
    }
    if (!await isAdmin()) throw StateError('صلاحية الإدارة مطلوبة');
    return _client!;
  }

  @override
  Future<List<Map<String, dynamic>>> accounts(int page) async {
    final client = await _authorized();
    final rows = await client
        .from('elnota_accounts')
        .select(
          'user_id,email,business_name,activated_at,cloud_until,cloud_plan,printing_enabled,suspended_at,deleted_at,created_at',
        )
        .order('created_at', ascending: false)
        .range(page * 50, page * 50 + 49);
    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    try {
      final overrides = await client
          .from('elnota_feature_access')
          .select('user_id,catalog_enabled')
          .inFilter('user_id', result.map((r) => r['user_id']).toList());
      for (final row in result) {
        row['catalog_enabled'] =
            overrides
                .where((f) => f['user_id'] == row['user_id'])
                .firstOrNull?['catalog_enabled'] ==
            true;
      }
    } catch (_) {
      /* Feature contract is staged, not deployed to legacy production. */
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> requests(int page) async {
    final client = await _authorized();
    final rows = await client
        .from('elnota_requests')
        .select('id,user_id,plan,amount,phone,reference,status,created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .range(page * 50, page * 50 + 49);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<void> review(String requestId, bool approve) async {
    final client = await _authorized(write: true);
    await client.rpc(
      'elnota_review',
      params: {'request_id': requestId, 'approve': approve},
    );
  }

  @override
  Future<void> setPrinting(String userId, bool enabled) async {
    final client = await _authorized(write: true);
    await client.rpc(
      'elnota_set_printing',
      params: {'target_user': userId, 'enabled': enabled},
    );
  }

  @override
  Future<void> setCatalog(String userId, bool enabled) async {
    final client = await _authorized(write: true);
    await client.rpc(
      'elnota_set_catalog_access',
      params: {'target_user': userId, 'enabled': enabled},
    );
  }

  @override
  Future<void> manageAccount(String userId, String operation) async {
    if (!['suspend', 'resume', 'restore'].contains(operation)) {
      throw ArgumentError('عملية غير مدعومة');
    }
    final client = await _authorized(write: true);
    await client.rpc(
      'elnota_manage_account',
      params: {'target_user': userId, 'operation': operation},
    );
  }

  @override
  Future<void> manageCloud(String userId, String plan) async {
    if (!['month', 'year', 'stop'].contains(plan)) {
      throw ArgumentError('خطة غير مدعومة');
    }
    final client = await _authorized(write: true);
    await client.rpc(
      'elnota_manage_cloud',
      params: {'target_user': userId, 'plan': plan},
    );
  }
}
