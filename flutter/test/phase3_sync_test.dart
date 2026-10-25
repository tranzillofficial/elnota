import 'package:flutter_test/flutter_test.dart';
import 'package:elnota/core/sync/models/sync_operation.dart';
import 'package:elnota/features/auth/models/user_session.dart';

void main() {
  group('SyncOperation Domain & Envelope Tests', () {
    test('serializes to remote protocol envelope with stable operation_id', () {
      final now = DateTime(2026, 10, 20, 12, 0, 0);
      final op = SyncOperation(
        operationId: 'op_uuid_123',
        workspaceId: 'ws_456',
        entityType: 'payment',
        entityId: 'pmt_789',
        operationType: 'create',
        payload: {
          'id': 'pmt_789',
          'amount_minor': 15000,
          'customer_id': 'cust_1',
        },
        baseVersion: 0,
        createdAt: now,
      );

      final envelope = op.toEnvelope();
      expect(envelope['operation_id'], 'op_uuid_123');
      expect(envelope['workspace_id'], 'ws_456');
      expect(envelope['entity_type'], 'payment');
      expect(envelope['entity_id'], 'pmt_789');
      expect(envelope['action'], 'create');
      expect(envelope['base_version'], 0);
      expect(envelope['schema_version'], 1);
      expect(envelope['created_at_client'], now.toIso8601String());
      expect(envelope['payload']['amount_minor'], 15000);
    });

    test('parses from database row map with JSON payload', () {
      final rowMap = {
        'operation_id': 'op_test_1',
        'workspace_id': 'default',
        'entity_type': 'customer',
        'entity_id': 'cust_99',
        'operation_type': 'create',
        'payload_json': '{"name":"Ahmad","phone":"01012345678"}',
        'base_version': 0,
        'created_at': 1760961600000,
        'attempts': 2,
        'status': 'pending',
      };

      final op = SyncOperation.fromMap(rowMap);
      expect(op.operationId, 'op_test_1');
      expect(op.workspaceId, 'default');
      expect(op.entityType, 'customer');
      expect(op.entityId, 'cust_99');
      expect(op.payload['name'], 'Ahmad');
      expect(op.payload['phone'], '01012345678');
      expect(op.attempts, 2);
      expect(op.isPending, isTrue);
      expect(op.isSending, isFalse);
      expect(op.isAcknowledged, isFalse);
      expect(op.needsAttention, isFalse);
    });

    test('verifies status flags correctly for needs_attention and acknowledged', () {
      final ackOp = SyncOperation(
        operationId: 'op_ack',
        workspaceId: 'ws_1',
        entityType: 'invoice',
        entityId: 'inv_1',
        operationType: 'create',
        payload: const {},
        createdAt: DateTime.now(),
        status: 'acknowledged',
      );
      expect(ackOp.isAcknowledged, isTrue);
      expect(ackOp.isPending, isFalse);

      final failedOp = SyncOperation(
        operationId: 'op_fail',
        workspaceId: 'ws_1',
        entityType: 'payment',
        entityId: 'pmt_2',
        operationType: 'create',
        payload: const {},
        createdAt: DateTime.now(),
        status: 'needs_attention',
        lastError: 'Unauthorized tenant access',
      );
      expect(failedOp.needsAttention, isTrue);
      expect(failedOp.lastError, 'Unauthorized tenant access');
    });
  });

  group('SyncSummary Observability Tests', () {
    test('computes hasPending and hasError flags accurately', () {
      const empty = SyncSummary(pendingCount: 0);
      expect(empty.hasPending, isFalse);
      expect(empty.hasError, isFalse);
      expect(empty.isSyncing, isFalse);

      const pending = SyncSummary(pendingCount: 3);
      expect(pending.hasPending, isTrue);
      expect(pending.hasError, isFalse);

      const withError = SyncSummary(
        pendingCount: 1,
        lastError: 'Network unreachable',
      );
      expect(withError.hasPending, isTrue);
      expect(withError.hasError, isTrue);
    });
  });

  group('Tenant Isolation & UserSession Tests', () {
    test('user session encapsulates workspace context and role', () {
      const session = UserSession(
        userId: 'usr_123',
        email: 'merchant@example.com',
        workspaceId: 'ws_tenant_99',
        workspaceName: 'المتجر الذهبي',
        role: 'owner',
      );

      expect(session.userId, 'usr_123');
      expect(session.email, 'merchant@example.com');
      expect(session.workspaceId, 'ws_tenant_99');
      expect(session.workspaceName, 'المتجر الذهبي');
      expect(session.isOwner, isTrue);
    });

    test('staff role is not owner', () {
      const session = UserSession(
        userId: 'usr_staff',
        email: 'clerk@example.com',
        workspaceId: 'ws_tenant_99',
        role: 'staff',
      );
      expect(session.isOwner, isFalse);
    });
  });
}
