// ignore_for_file: public_member_api_docs
// Wave 16: Sync Engine domain models.
// Pure Dart representations of outbox items, sync batches, and engine state.

import 'dart:convert';

import '../../../data/drift/app_database.dart';

enum SyncStatus { pending, inFlight, completed, failed }

enum SyncConnectionState { online, offline, syncing, error, idle, partialFailure }

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
      'payload': jsonDecode(payloadJson),
    };
  }
}

class SyncAcknowledgement {
  final int seq;
  final String status;

  const SyncAcknowledgement({required this.seq, required this.status});
}

class SyncTransportException implements Exception {
  final String message;
  final String code;
  final bool retryable;

  const SyncTransportException({
    required this.message,
    required this.code,
    required this.retryable,
  });

  @override
  String toString() => 'SyncTransportException($code): $message';
}

abstract interface class SyncTransport {
  Future<List<SyncAcknowledgement>> pushBatch({
    required String userId,
    required String deviceId,
    required List<SyncItem> items,
  });

  Future<void> pullChanges({
    required String userId,
    required String deviceId,
    required AppDatabase database,
  });
}

abstract interface class SyncOutboxStore {
  Future<List<SyncItem>> loadPending(String userId, {int limit = 50});
  Future<int> countPending(String userId);
  Future<void> markAcknowledged(List<int> seqs);
  Future<void> recordFailure({
    required int seq,
    required String errorClass,
    required String errorCode,
    required Duration backoff,
    required bool retryable,
    int maxAttempts = 3,
  });
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
