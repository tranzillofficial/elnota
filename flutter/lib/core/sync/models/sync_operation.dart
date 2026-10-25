import 'dart:convert';

/// Represents a single mutation operation recorded locally and pending cloud sync.
class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    this.baseVersion = 0,
    required this.createdAt,
    this.attempts = 0,
    this.nextRetryAt,
    this.status = 'pending',
    this.lastError,
  });

  final String operationId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final int baseVersion;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextRetryAt;
  final String status;
  final String? lastError;

  bool get isPending => status == 'pending';
  bool get isSending => status == 'sending';
  bool get isAcknowledged => status == 'acknowledged';
  bool get needsAttention => status == 'needs_attention';

  /// Serialize envelope for remote push.
  Map<String, dynamic> toEnvelope() => {
    'operation_id': operationId,
    'workspace_id': workspaceId,
    'entity_type': entityType,
    'entity_id': entityId,
    'action': operationType,
    'base_version': baseVersion,
    'schema_version': 1,
    'created_at_client': createdAt.toIso8601String(),
    'payload': payload,
  };

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    if (map['payload_json'] is String) {
      try {
        parsedPayload =
            jsonDecode(map['payload_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    } else if (map['payload'] is Map<String, dynamic>) {
      parsedPayload = map['payload'] as Map<String, dynamic>;
    }

    return SyncOperation(
      operationId: map['operation_id'] as String,
      workspaceId: map['workspace_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operationType: map['operation_type'] as String,
      payload: parsedPayload,
      baseVersion: (map['base_version'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      attempts: (map['attempts'] as int?) ?? 0,
      nextRetryAt: map['next_retry_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['next_retry_at'] as int)
          : null,
      status: (map['status'] as String?) ?? 'pending',
      lastError: map['last_error'] as String?,
    );
  }
}

/// Represents the synchronization summary state.
class SyncSummary {
  const SyncSummary({
    required this.pendingCount,
    this.lastSuccessAt,
    this.isSyncing = false,
    this.lastError,
  });

  final int pendingCount;
  final DateTime? lastSuccessAt;
  final bool isSyncing;
  final String? lastError;

  bool get hasPending => pendingCount > 0;
  bool get hasError => lastError != null && lastError!.isNotEmpty;
}
