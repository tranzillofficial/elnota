import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../database/app_database.dart';
import '../../database/database_impl.dart';
import '../../network/connectivity_service.dart';
import '../../services/supabase_service.dart';
import '../../services/account_access_service.dart';
import '../models/sync_operation.dart';
import '../models/cloud_snapshot.dart';
import '../../utils/app_runtime.dart';

/// Versioned snapshots are merged by stable row identity. The server enforces
/// tenant ownership, subscription, CAS and immutable financial history.
class SyncService extends GetxService with WidgetsBindingObserver {
  static const ledgerCloudEnabled =
      !AppRuntime.demo &&
      bool.fromEnvironment('ENABLE_RELATIONAL_SYNC', defaultValue: false);
  static SyncService get to => Get.find<SyncService>();
  SyncService({AppDao? dao}) : _dao = dao ?? DatabaseService.to.dao;
  final AppDao _dao;
  final summary = const SyncSummary(pendingCount: 0).obs;
  StreamSubscription<int>? _pending;
  StreamSubscription<void>? _reconnect;
  Timer? _timer, _debounce;
  bool _running = false;
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _pending = _dao.watchPendingOutboxCount().listen((count) {
      if (isClosed) return;
      summary.value = SyncSummary(
        pendingCount: count,
        lastSuccessAt: summary.value.lastSuccessAt,
        isSyncing: summary.value.isSyncing,
        lastError: summary.value.lastError,
      );
      if (count > 0 && ledgerCloudEnabled) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 750), () => syncNow());
      }
    });
    if (Get.isRegistered<ConnectivityService>()) {
      _reconnect = ConnectivityService.to.onReconnect.listen((_) => syncNow());
    }
    if (ledgerCloudEnabled) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
      Future.microtask(syncNow);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  Future<bool> syncNow() async {
    if (!ledgerCloudEnabled) return false;
    if (_running ||
        isClosed ||
        !Get.isRegistered<AccountAccessService>() ||
        !Get.isRegistered<SupabaseService>() ||
        !Get.isRegistered<ConnectivityService>() ||
        !ConnectivityService.to.isOnline.value) {
      return false;
    }
    final client = SupabaseService.to.client,
        uid = SupabaseService.to.client?.auth.currentUser?.id;
    if (client == null || uid == null) return false;
    _running = true;
    bool valid() => !isClosed && client.auth.currentUser?.id == uid;
    try {
      await AccountAccessService.to.refreshAccess();
      if (!valid() ||
          !AccountAccessService.to.onlineVerified.value ||
          !AccountAccessService.to.access.value.active ||
          AccountAccessService.to.access.value.cloudUntil == null) {
        return false;
      }
      final canWrite = AccountAccessService.to.cloudEnabled;
      summary.value = SyncSummary(
        pendingCount: summary.value.pendingCount,
        lastSuccessAt: summary.value.lastSuccessAt,
        isSyncing: true,
      );
      final baseline = await _dao.cloudBaseline();
      final rawLocal = await _dao.exportLocalSnapshot();
      final profileKey = 'business_profile:$uid';
      rawLocal['business_profile'] = GetStorage().read<Map>(profileKey) ?? {};
      final local = CloudSnapshot.normalize(rawLocal);
      final ops = (rawLocal['sync_outbox'] as List)
          .where((o) => o['status'] != 'acknowledged')
          .map((o) => o['operation_id'] as String)
          .toList();
      final head = await client
          .from('elnota_v2_cloud')
          .select('revision')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 30));
      final revision = (head?['revision'] as num?)?.toInt() ?? 0;
      final base = baseline == null
          ? CloudSnapshot.empty()
          : Map<String, dynamic>.from(baseline['data'] as Map);
      final Map<String, dynamic> remote;
      if (head == null) {
        remote = CloudSnapshot.empty();
      } else if (revision == baseline?['revision']) {
        remote = base;
      } else {
        final row = await client
            .from('elnota_v2_cloud')
            .select('revision,data')
            .eq('user_id', uid)
            .single()
            .timeout(const Duration(seconds: 30));
        // Use the revision belonging to this exact data page, not the earlier head.
        head['revision'] = row['revision'];
        remote = CloudSnapshot.normalize(
          Map<String, dynamic>.from(row['data'] as Map),
        );
      }
      final expected = (head?['revision'] as num?)?.toInt() ?? 0;
      final merged = CloudSnapshot.merge(
        baseline: base,
        local: local,
        remote: remote,
      );
      if (!valid()) return false;
      if (!CloudSnapshot.same(local, merged)) {
        await _dao.applyCloudSnapshot(expectedLocal: local, merged: merged);
      }
      if (!valid()) return false;
      final next =
          !canWrite || (CloudSnapshot.same(merged, remote) && head != null)
          ? expected
          : (await client
                        .rpc(
                          'elnota_v2_commit',
                          params: {
                            'expected_user': uid,
                            'expected_revision': expected,
                            'payload': merged,
                          },
                        )
                        .timeout(const Duration(seconds: 45))
                    as num)
                .toInt();
      if (!valid()) return false;
      final currentProfile = GetStorage().read<Map>(profileKey) ?? {};
      final currentNormalized = CloudSnapshot.normalize({
        'business_profile': currentProfile,
      })['business_profile'];
      if (valid() &&
          CloudSnapshot.same(currentNormalized, local['business_profile'])) {
        await GetStorage().write(profileKey, {
          ...currentProfile,
          ...Map<String, dynamic>.from(merged['business_profile'] as Map),
        });
      }
      if (!valid()) return false;
      await _dao.saveCloudBaseline(
        canWrite ? merged : remote,
        next,
        canWrite || CloudSnapshot.same(local, remote) ? ops : [],
      );
      if (valid()) {
        summary.value = SyncSummary(
          pendingCount: summary.value.pendingCount,
          lastSuccessAt: DateTime.now(),
        );
      }
      return true;
    } catch (e) {
      if (valid()) {
        final raw = e.toString();
        final message = e is CloudConflict
            ? e.toString()
            : raw.contains('LEGACY_')
            ? 'يوجد دفتر كلاود قديم. استورد نسخته أولًا؛ لم تتغير بياناته.'
            : raw.contains('REVISION_CONFLICT') ||
                  raw.contains('LOCAL_CHANGED_RETRY')
            ? 'وصل تحديث أثناء المزامنة؛ التغييرات محفوظة وستُعاد المحاولة.'
            : raw.contains('IMMUTABLE')
            ? 'تعارض في سجل مالي محفوظ. لم يتم استبداله؛ احتفظ بنسخة وراجع الدعم.'
            : raw.contains('TOO_LARGE')
            ? 'حجم دفتر الكلاود تجاوز 10 ميجابايت؛ صدّر نسخة وراجع الإدارة.'
            : 'تعذر الاتصال بالكلاود؛ تغييرات هذا الجهاز محفوظة وستُعاد المحاولة.';
        summary.value = SyncSummary(
          pendingCount: summary.value.pendingCount,
          lastSuccessAt: summary.value.lastSuccessAt,
          lastError: message,
        );
        await _dao.updateSyncState(lastError: message);
      }
      return false;
    } finally {
      _running = false;
      if (valid() && summary.value.isSyncing) {
        summary.value = SyncSummary(
          pendingCount: summary.value.pendingCount,
          lastSuccessAt: summary.value.lastSuccessAt,
          lastError: summary.value.lastError,
        );
      }
    }
  }

  Future<bool> pushPendingOutbox({int batchSize = 50}) => syncNow();
  Future<bool> pullRemoteChanges() => syncNow();
  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _pending?.cancel();
    _reconnect?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    super.onClose();
  }
}
