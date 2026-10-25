import 'dart:async';
import 'package:get/get.dart';
import '../../database/app_database.dart';
import '../../database/database_impl.dart';
import '../../network/connectivity_service.dart';
import '../../services/supabase_service.dart';
import '../models/sync_operation.dart';
import '../../services/account_access_service.dart';
import '../../utils/app_runtime.dart';

class SyncService extends GetxService {
  static const ledgerCloudEnabled =
      !AppRuntime.demo &&
      bool.fromEnvironment('ENABLE_RELATIONAL_SYNC', defaultValue: false);
  static SyncService get to => Get.find<SyncService>();

  SyncService({AppDao? dao}) : _dao = dao ?? DatabaseService.to.dao;

  final AppDao _dao;
  final Rx<SyncSummary> summary = const SyncSummary(pendingCount: 0).obs;

  StreamSubscription<int>? _pendingCountSub;
  StreamSubscription<void>? _reconnectSub;

  @override
  void onInit() {
    super.onInit();
    _initObservers();
  }

  void _initObservers() {
    _pendingCountSub = _dao.watchPendingOutboxCount().listen((cnt) {
      summary.value = SyncSummary(
        pendingCount: cnt,
        lastSuccessAt: summary.value.lastSuccessAt,
        isSyncing: summary.value.isSyncing,
        lastError: summary.value.lastError,
      );
    });

    if (Get.isRegistered<ConnectivityService>()) {
      _reconnectSub = ConnectivityService.to.onReconnect.listen((_) {
        syncNow();
      });
    }
  }

  /// Triggers a full push and pull synchronization cycle.
  Future<bool> syncNow() async {
    if (!ledgerCloudEnabled) {
      summary.value = SyncSummary(
        pendingCount: summary.value.pendingCount,
        lastSuccessAt: summary.value.lastSuccessAt,
        lastError: 'المزامنة العلائقية غير مفعّلة لحماية بيانات الموقع الحالي',
      );
      return false;
    }
    if (!Get.isRegistered<AccountAccessService>() ||
        !AccountAccessService.to.cloudEnabled) {
      return false;
    }
    if (summary.value.isSyncing) return false;

    summary.value = SyncSummary(
      pendingCount: summary.value.pendingCount,
      lastSuccessAt: summary.value.lastSuccessAt,
      isSyncing: true,
      lastError: null,
    );

    try {
      final pushSuccess = await pushPendingOutbox();
      final pullSuccess = await pullRemoteChanges();

      final now = DateTime.now();
      summary.value = SyncSummary(
        pendingCount: summary.value.pendingCount,
        lastSuccessAt: (pushSuccess || pullSuccess)
            ? now
            : summary.value.lastSuccessAt,
        isSyncing: false,
        lastError: null,
      );

      if (pushSuccess || pullSuccess) {
        await _dao.updateSyncState(lastSuccessAt: now.millisecondsSinceEpoch);
      }
      return true;
    } catch (e) {
      summary.value = SyncSummary(
        pendingCount: summary.value.pendingCount,
        lastSuccessAt: summary.value.lastSuccessAt,
        isSyncing: false,
        lastError: e.toString(),
      );
      await _dao.updateSyncState(lastError: e.toString());
      return false;
    }
  }

  /// Pushes pending outbox mutations to the cloud idempotently.
  Future<bool> pushPendingOutbox({int batchSize = 50}) async {
    if (!ledgerCloudEnabled ||
        !Get.isRegistered<AccountAccessService>() ||
        !AccountAccessService.to.cloudEnabled) {
      return false;
    }
    final rawRows = await _dao.getPendingOutbox(limit: batchSize);
    if (rawRows.isEmpty) return true;

    final ops = rawRows.map(SyncOperation.fromMap).toList();
    final opIds = ops.map((o) => o.operationId).toList();

    await _dao.markOutboxSending(opIds);

    final supa = Get.isRegistered<SupabaseService>()
        ? SupabaseService.to
        : null;
    final isOnline = Get.isRegistered<ConnectivityService>()
        ? ConnectivityService.to.isOnline.value
        : false;

    // If Supabase client is not ready or offline, return to pending without error
    if (supa == null ||
        !supa.isInitialized ||
        supa.client == null ||
        !isOnline) {
      // Revert from sending back to pending
      for (final op in ops) {
        await _dao.markOutboxFailed(
          op.operationId,
          'Offline: Waiting for network',
          isPermanent: false,
        );
      }
      return false;
    }

    final client = supa.client!;
    final List<String> acknowledged = [];

    for (final op in ops) {
      try {
        // RPC push or direct table upsert keyed by operation_id / id
        final response = await client.from('sync_inbox').insert({
          'operation_id': op.operationId,
          'workspace_id': op.workspaceId,
          'entity_type': op.entityType,
          'entity_id': op.entityId,
          'action': op.operationType,
          'payload': op.payload,
          'client_created_at': op.createdAt.toIso8601String(),
        }).select();

        if (response.isNotEmpty) {
          acknowledged.add(op.operationId);
        }
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isDuplicate =
            errStr.contains('duplicate') || errStr.contains('23505');
        if (isDuplicate) {
          // Idempotency: duplicate operation_id is safely treated as acknowledged
          acknowledged.add(op.operationId);
        } else {
          final isPermanent =
              errStr.contains('unauthorized') ||
              errStr.contains('violates') ||
              errStr.contains('foreign key');
          await _dao.markOutboxFailed(
            op.operationId,
            e.toString(),
            isPermanent: isPermanent,
          );
        }
      }
    }

    if (acknowledged.isNotEmpty) {
      await _dao.markOutboxAcknowledged(acknowledged);
    }

    return true;
  }

  /// Pulls remote delta updates after last recorded cursor.
  Future<bool> pullRemoteChanges() async {
    if (!ledgerCloudEnabled ||
        !Get.isRegistered<AccountAccessService>() ||
        !AccountAccessService.to.cloudEnabled) {
      return false;
    }
    final supa = Get.isRegistered<SupabaseService>()
        ? SupabaseService.to
        : null;
    final isOnline = Get.isRegistered<ConnectivityService>()
        ? ConnectivityService.to.isOnline.value
        : false;

    if (supa == null ||
        !supa.isInitialized ||
        supa.client == null ||
        !isOnline) {
      return false;
    }

    final syncState = await _dao.getSyncState();
    final lastCursor = syncState?['last_cursor'] as String?;

    try {
      // Query incremental updates from workspace sync stream
      var filterQuery = supa.client!.from('sync_outbox_events').select();
      if (lastCursor != null) {
        filterQuery = filterQuery.gt('cursor', lastCursor);
      }
      final events = await filterQuery
          .order('cursor', ascending: true)
          .limit(100);

      if (events.isNotEmpty) {
        final newCursor = events.last['cursor']?.toString();
        if (newCursor != null) {
          await _dao.updateSyncState(lastCursor: newCursor);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _pendingCountSub?.cancel();
    _reconnectSub?.cancel();
    super.onClose();
  }
}
