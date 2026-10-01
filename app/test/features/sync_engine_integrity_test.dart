import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/sync/domain/sync_engine.dart';
import 'package:kratos_app/features/sync/domain/sync_models.dart';

void main() {
  late _FakeOutbox outbox;
  late _FakeTransport transport;
  late SyncEngine engine;

  setUp(() {
    outbox = _FakeOutbox([_item()]);
    transport = _FakeTransport();
    engine = SyncEngine(
      outbox: outbox,
      transport: transport,
      userId: 'user-a',
      deviceId: 'device-a',
    );
  });

  tearDown(() => engine.dispose());

  test(
    'marks an operation done only after matching server acknowledgement',
    () async {
      transport.send = (items) async => [
        SyncAcknowledgement(seq: items.single.seq, status: 'applied'),
      ];

      final result = await engine.triggerDrain();

      expect(result.isSuccess, isTrue);
      expect(outbox.acknowledged, [1]);
      expect(outbox.items, isEmpty);
      expect(transport.calls, 1);
    },
  );

  test('transport failure preserves row and schedules retry', () async {
    transport.send = (_) async => throw const SyncTransportException(
      message: 'offline',
      code: 'network',
      retryable: true,
    );

    final result = await engine.triggerDrain();

    expect(result.isSuccess, isFalse);
    expect(outbox.items, hasLength(1));
    expect(outbox.items.single.attempts, 1);
    expect(outbox.items.single.status, SyncStatus.pending);
    expect(outbox.retryTimes, hasLength(1));
  });

  test('incomplete acknowledgement cannot clear an operation', () async {
    transport.send = (_) async => const [];

    final result = await engine.triggerDrain();

    expect(result.isSuccess, isFalse);
    expect(outbox.acknowledged, isEmpty);
    expect(outbox.items.single.attempts, 1);
  });

  test('permanent failure parks operation without dropping it', () async {
    transport.send = (_) async => throw const SyncTransportException(
      message: 'unsupported operation',
      code: '0A000',
      retryable: false,
    );

    await engine.triggerDrain();

    expect(outbox.items, hasLength(1));
    expect(outbox.items.single.status, SyncStatus.failed);
    expect(outbox.items.single.attempts, 1);
  });

  test('wire payload contains decoded JSON object', () {
    expect(_item().toBatchPayload()['payload'], {'title': 'Retain'});
  });

  test(
    'empty local queue is not reported as a successful online sync',
    () async {
      outbox.items.clear();

      final result = await engine.triggerDrain();

      expect(result.isSuccess, isFalse);
      expect(engine.currentState, SyncConnectionState.offline);
      expect(transport.calls, 0);
    },
  );

  test('HLC serialization preserves the full device identifier', () {
    final deviceId = Id.uuidV7();
    final parsed = Hlc.parse(Hlc.now(deviceId).toString());
    expect(parsed.nodeId, deviceId);
  });

  test('HLC merge stamps the local node identity when provided', () {
    final localNode = Id.uuidV7();
    final left = Hlc(wallMs: 10, counter: 1, nodeId: Id.uuidV7());
    final right = Hlc(wallMs: 10, counter: 2, nodeId: Id.uuidV7());

    expect(
      Hlc.merge(left, right, nowMs: 10, nodeId: localNode).nodeId,
      localNode,
    );
  });
}

SyncItem _item({int attempts = 0, SyncStatus status = SyncStatus.pending}) =>
    SyncItem(
      seq: 1,
      userId: 'user-a',
      op: 'upsert',
      entity: 'tasks',
      entityId: 'task-a',
      payloadJson: '{"title":"Retain"}',
      hlc: 'Hlc(wall=1, c=0, node=00000000)',
      deviceId: 'device-a',
      attempts: attempts,
      status: status,
      createdAt: DateTime.utc(2026),
    );

class _FakeOutbox implements SyncOutboxStore {
  _FakeOutbox(this.items);
  final List<SyncItem> items;
  final List<int> acknowledged = [];
  final List<DateTime> retryTimes = [];

  @override
  Future<List<SyncItem>> loadPending(String userId, {int limit = 50}) async =>
      items
          .where(
            (item) =>
                item.userId == userId && item.status == SyncStatus.pending,
          )
          .take(limit)
          .toList();

  @override
  Future<int> countPending(String userId) async => items
      .where(
        (item) => item.userId == userId && item.status == SyncStatus.pending,
      )
      .length;

  @override
  Future<void> markAcknowledged(List<int> seqs) async {
    acknowledged.addAll(seqs);
    items.removeWhere((item) => seqs.contains(item.seq));
  }

  @override
  Future<void> recordFailure({
    required int seq,
    required String errorClass,
    required String errorCode,
    required Duration backoff,
    required bool retryable,
    int maxAttempts = 3,
  }) async {
    final index = items.indexWhere((item) => item.seq == seq);
    if (index < 0) return;
    final item = items[index];
    final attempts = item.attempts + 1;
    final parked = !retryable || attempts >= maxAttempts;
    final retryAt = parked ? null : DateTime.now().toUtc().add(backoff);
    items[index] = SyncItem(
      seq: item.seq,
      userId: item.userId,
      op: item.op,
      entity: item.entity,
      entityId: item.entityId,
      payloadJson: item.payloadJson,
      hlc: item.hlc,
      deviceId: item.deviceId,
      idempotencyKey: item.idempotencyKey,
      attempts: attempts,
      status: parked ? SyncStatus.failed : SyncStatus.pending,
      createdAt: item.createdAt,
    );
    if (retryAt != null) retryTimes.add(retryAt);
  }
}

class _FakeTransport implements SyncTransport {
  Future<List<SyncAcknowledgement>> Function(List<SyncItem>) send = (_) async =>
      const [];
  int calls = 0;

  @override
  Future<List<SyncAcknowledgement>> pushBatch({
    required String userId,
    required String deviceId,
    required List<SyncItem> items,
  }) {
    calls++;
    return send(items);
  }

  @override
  Future<void> pullChanges({
    required String userId,
    required String deviceId,
    required AppDatabase database,
  }) async {}
}
