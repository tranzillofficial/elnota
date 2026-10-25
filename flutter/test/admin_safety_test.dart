import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:elnota/features/admin/controllers/admin_controller.dart';
import 'package:elnota/features/admin/repositories/admin_repository.dart';
import 'package:elnota/core/database/database_impl.dart';
import 'package:elnota/core/sync/services/sync_service.dart';

class _AdminGateway implements AdminGateway {
  @override
  Future<void> setCatalog(String id, bool enabled) async {
    writes++;
  }

  bool authorized = false;
  bool fail = false;
  int reads = 0;
  int writes = 0;
  @override
  Future<bool> isAdmin() async => authorized;
  @override
  Future<List<Map<String, dynamic>>> accounts(int page) async {
    reads++;
    if (fail) throw StateError('offline');
    return [
      {'user_id': 'u1', 'email': 'admin-fixture@example.test'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> requests(int page) async {
    reads++;
    return [];
  }

  @override
  Future<void> review(String requestId, bool approve) async {
    writes++;
  }

  @override
  Future<void> setPrinting(String userId, bool enabled) async {
    writes++;
  }
}

class _NoCloudDao implements AppDao {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No database or cloud operation expected');
}

void main() {
  tearDown(() => Get.reset());
  test('non-admin cannot request account rows', () async {
    final gateway = _AdminGateway();
    final ctrl = AdminController(gateway);
    await ctrl.refreshData();
    expect(ctrl.allowed.value, false);
    expect(gateway.reads, 0);
    expect(ctrl.accountRows, isEmpty);
  });
  test('administrator can read; writes are disabled by default', () async {
    final gateway = _AdminGateway()..authorized = true;
    final ctrl = AdminController(gateway);
    await ctrl.refreshData();
    expect(ctrl.allowed.value, true);
    expect(ctrl.accountRows.single['user_id'], 'u1');
    expect(await ctrl.reviewRequest('request-1', true), false);
    expect(await ctrl.changePrinting('u1', true), false);
    expect(gateway.writes, 0);
  });
  test('lost admin permission clears previously loaded rows', () async {
    final gateway = _AdminGateway()..authorized = true;
    final ctrl = AdminController(gateway);
    await ctrl.refreshData();
    gateway.authorized = false;
    await ctrl.refreshData();
    expect(ctrl.accountRows, isEmpty);
    expect(ctrl.allowed.value, false);
  });
  test(
    'cloud ledger remains disconnected from the legacy production account',
    () async {
      expect(SyncService.ledgerCloudEnabled, false);
      final sync = SyncService(dao: _NoCloudDao());
      expect(await sync.syncNow(), false);
      expect(await sync.pushPendingOutbox(), false);
      expect(await sync.pullRemoteChanges(), false);
    },
  );
}
