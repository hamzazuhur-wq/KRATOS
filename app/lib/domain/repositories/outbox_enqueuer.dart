// ignore_for_file: public_member_api_docs

import '../hlc.dart';
import '../ids.dart';

/// Operations captured by the outbox. The repo writes a row per
/// entity mutation inside the same Drift transaction.
enum OutboxOp { create, update, delete }

abstract interface class OutboxEnqueuer {
  Future<void> enqueue({
    required Id ownerId,
    required OutboxOp op,
    required String entity,
    required String entityId,
    required Map<String, Object?> payload,
    required Hlc hlc,
    required String deviceId,
  });
}
