// ignore_for_file: public_member_api_docs
// Wave 16: Sync Engine domain models.
// Pure Dart representations of outbox items, sync batches, and engine state.

enum SyncStatus {
  pending,
  inFlight,
  completed,
  failed,
}

enum SyncConnectionState {
  online,
  offline,
  syncing,
  error,
}

class SyncItem {
  final int seq;
  final String userId;
  final String op;
  final String entity;
  final String entityId;
  final String payloadJson;
  final String hlc;
  final String deviceId;
  final String? idempotencyKey;
  final int attempts;
  final SyncStatus status;
  final DateTime createdAt;

  const SyncItem({
    required this.seq,
    required this.userId,
    required this.op,
    required this.entity,
    required this.entityId,
    required this.payloadJson,
    required this.hlc,
    required this.deviceId,
    required this.attempts,
    required this.status,
    required this.createdAt,
    this.idempotencyKey,
  });

  Map<String, dynamic> toBatchPayload() {
    return {
      'seq': seq,
      'op': op,
      'entity': entity,
      'entity_id': entityId,
      'hlc': hlc,
      'payload': payloadJson,
    };
  }
}

class SyncResult {
  final int applied;
  final int skipped;
  final bool isSuccess;
  final String? errorMessage;

  const SyncResult({
    required this.applied,
    required this.skipped,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory SyncResult.failure(String message) {
    return SyncResult(
      applied: 0,
      skipped: 0,
      isSuccess: false,
      errorMessage: message,
    );
  }
}
