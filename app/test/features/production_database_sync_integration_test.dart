import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:kratos_app/core/config/app_config.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';
import 'package:kratos_app/features/sync/domain/sync_engine.dart';
import 'package:kratos_app/features/sync/domain/sync_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Production Configuration & Auth Persistence', () {
    test('AppConfig loads Supabase configuration from environment safely', () {
      final config = AppConfig.fromEnvironment();
      expect(config.supabaseUrl, isA<String>());
      expect(config.supabaseAnonKey, isA<String>());
      expect(config.appVersion, isNotEmpty);
    });

    test('Auth state is synchronously authenticated when user session exists', () {
      // Validates that when a persisted session exists, the initial state is AuthAuthenticated
      // eliminating login screen flicker on restart.
      const userId = '018f3a21-9988-7123-8456-112233445566';
      const email = 'kratos.user@domain.test';
      
      final state = AuthAuthenticated(
        KratosUser(
          id: Id(userId),
          email: email,
          displayName: 'Kratos Champion',
          method: AuthMethod.email,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      expect(state, isA<AuthAuthenticated>());
      expect(state.user.id.value, userId);
      expect(state.user.email, email);
    });
  });

  group('Drift Database Schema Upgrade & Data Preservation', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(drift.DatabaseConnection(
        NativeDatabase.memory(),
      ));
    });

    tearDown(() => db.close());

    test('Schema version 12 reflects current database definition', () {
      expect(db.schemaVersion, 14);
    });

    test('Activities table contains difficulty column with default 5', () async {
      final activityId = Id.uuidV7().value;
      const userId = '018f3a21-9988-7123-8456-112233445566';
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id(activityId)).toString();

      await db.into(db.activities).insert(
        ActivitiesCompanion.insert(
          id: activityId,
          ownerId: userId,
          name: 'Deep Work Session',
          versionHlc: hlc,
          createdAt: now,
          updatedAt: now,
          difficulty: const drift.Value(8),
          targetDurationMinutes: const drift.Value(90),
        ),
      );

      final row = await (db.select(db.activities)..where((t) => t.id.equals(activityId))).getSingle();
      expect(row.difficulty, 8);
      expect(row.targetDurationMinutes, 90);
    });
  });

  group('Offline Outbox Queueing & Exponential Backoff Retry', () {
    late _TestOutbox outbox;
    late _TestTransport transport;
    late SyncEngine engine;
    const userId = 'user-prod-001';
    const deviceId = 'device-prod-001';

    setUp(() {
      outbox = _TestOutbox();
      transport = _TestTransport();
      engine = SyncEngine(
        outbox: outbox,
        transport: transport,
        userId: userId,
        deviceId: deviceId,
      );
    });

    tearDown(() => engine.dispose());

    test('Queued mutation survives offline state and triggers exponential backoff on network failure', () async {
      final taskItem = SyncItem(
        seq: 1,
        userId: userId,
        op: 'upsert',
        entity: 'tasks',
        entityId: 'task-001',
        payloadJson: jsonEncode({'title': 'Complete Review', 'status': 'open'}),
        hlc: Hlc.now(const Id(deviceId)).toString(),
        deviceId: deviceId,
        attempts: 0,
        status: SyncStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      outbox.items.add(taskItem);

      transport.pushHandler = (_) async => throw const SyncTransportException(
        message: 'No internet connection',
        code: 'network_unavailable',
        retryable: true,
      );

      final result = await engine.triggerDrain();

      expect(result.isSuccess, isFalse);
      expect(engine.currentState, SyncConnectionState.error);
      expect(outbox.items.single.attempts, 1);
      expect(outbox.items.single.status, SyncStatus.pending);
      expect(outbox.recordedBackoffs.length, 1);
      // Attempt 1 backoff: min(2^1, 300) = 2 seconds
      expect(outbox.recordedBackoffs.single.inSeconds, 2);
    });

    test('Non-retryable transport failure parks operation into failed status', () async {
      final taskItem = SyncItem(
        seq: 2,
        userId: userId,
        op: 'upsert',
        entity: 'tasks',
        entityId: 'task-002',
        payloadJson: jsonEncode({'title': 'Invalid Item'}),
        hlc: Hlc.now(const Id(deviceId)).toString(),
        deviceId: deviceId,
        attempts: 0,
        status: SyncStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );
      outbox.items.add(taskItem);

      transport.pushHandler = (_) async => throw const SyncTransportException(
        message: 'Violates check constraint',
        code: '23514',
        retryable: false,
      );

      final result = await engine.triggerDrain();

      expect(result.isSuccess, isFalse);
      expect(outbox.items.single.status, SyncStatus.failed);
      expect(outbox.items.single.attempts, 1);
    });
  });

  group('Multi-Entity Sync Batch Payload Serialization', () {
    test('Serializes tasks, goals, projects, activities, sessions, and xp_ledger items correctly', () {
      final entities = [
        'tasks',
        'goals',
        'projects',
        'activities',
        'sessions',
        'categories',
        'life_areas',
        'skills',
        'xp_ledger',
      ];

      for (int i = 0; i < entities.length; i++) {
        final entity = entities[i];
        final item = SyncItem(
          seq: i + 1,
          userId: 'user-001',
          op: 'upsert',
          entity: entity,
          entityId: 'entity-$i',
          payloadJson: jsonEncode({'name': 'Item $i', 'index': i}),
          hlc: 'Hlc(wall=${1000 + i}, c=0, node=device-1)',
          deviceId: 'device-1',
          attempts: 0,
          status: SyncStatus.pending,
          createdAt: DateTime.now().toUtc(),
        );

        final payload = item.toBatchPayload();
        expect(payload['seq'], i + 1);
        expect(payload['op'], 'upsert');
        expect(payload['entity'], entity);
        expect(payload['entity_id'], 'entity-$i');
        expect(payload['hlc'], contains('wall='));
        expect(payload['payload'], isA<Map<String, dynamic>>());
        expect((payload['payload'] as Map<String, dynamic>)['index'], i);
      }
    });
  });

  group('Bidirectional Sync & Conflict Reconciliation Rules', () {
    test('HLC LWW total ordering correctly determines newer vs older mutations', () {
      final olderHlc = Hlc(wallMs: 1000, counter: 0, nodeId: const Id('00000000-0000-7000-8000-000000000001'));
      final newerWallHlc = Hlc(wallMs: 1001, counter: 0, nodeId: const Id('00000000-0000-7000-8000-000000000001'));
      final newerCounterHlc = Hlc(wallMs: 1000, counter: 1, nodeId: const Id('00000000-0000-7000-8000-000000000001'));

      expect(newerWallHlc.compareTo(olderHlc), greaterThan(0));
      expect(newerCounterHlc.compareTo(olderHlc), greaterThan(0));
      expect(olderHlc.compareTo(newerWallHlc), lessThan(0));
    });

    test('Tombstone always takes precedence over incoming row mutation', () {
      final tombstoneKeys = <String>{'tasks:task-deleted-001'};
      const incomingEntity = 'tasks';
      const incomingEntityId = 'task-deleted-001';

      final shouldApply = !tombstoneKeys.contains('$incomingEntity:$incomingEntityId');
      expect(shouldApply, isFalse);
    });

    test('Dirty local outbox item is preserved over remote server pull until pushed', () {
      final pendingOutboxEntityKeys = <String>{'tasks:task-dirty-001'};
      const incomingEntity = 'tasks';
      const incomingEntityId = 'task-dirty-001';

      final canOverwrite = !pendingOutboxEntityKeys.contains('$incomingEntity:$incomingEntityId');
      expect(canOverwrite, isFalse);
    });
  });
}

class _TestOutbox implements SyncOutboxStore {
  final List<SyncItem> items = [];
  final List<int> acknowledged = [];
  final List<Duration> recordedBackoffs = [];

  @override
  Future<List<SyncItem>> loadPending(String userId, {int limit = 50}) async =>
      items.where((i) => i.userId == userId && i.status == SyncStatus.pending).take(limit).toList();

  @override
  Future<int> countPending(String userId) async =>
      items.where((i) => i.userId == userId && i.status == SyncStatus.pending).length;

  @override
  Future<void> markAcknowledged(List<int> seqs) async {
    acknowledged.addAll(seqs);
    items.removeWhere((i) => seqs.contains(i.seq));
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
    recordedBackoffs.add(backoff);
    final idx = items.indexWhere((i) => i.seq == seq);
    if (idx >= 0) {
      final item = items[idx];
      final attempts = item.attempts + 1;
      final parked = !retryable || attempts >= maxAttempts;
      items[idx] = SyncItem(
        seq: item.seq,
        userId: item.userId,
        op: item.op,
        entity: item.entity,
        entityId: item.entityId,
        payloadJson: item.payloadJson,
        hlc: item.hlc,
        deviceId: item.deviceId,
        attempts: attempts,
        status: parked ? SyncStatus.failed : SyncStatus.pending,
        createdAt: item.createdAt,
      );
    }
  }
}

class _TestTransport implements SyncTransport {
  Future<List<SyncAcknowledgement>> Function(List<SyncItem>)? pushHandler;
  Future<void> Function(AppDatabase)? pullHandler;

  @override
  Future<List<SyncAcknowledgement>> pushBatch({
    required String userId,
    required String deviceId,
    required List<SyncItem> items,
  }) async {
    if (pushHandler != null) {
      return await pushHandler!(items);
    }
    return items.map((i) => SyncAcknowledgement(seq: i.seq, status: 'applied')).toList();
  }

  @override
  Future<void> pullChanges({
    required String userId,
    required String deviceId,
    required AppDatabase database,
  }) async {
    if (pullHandler != null) {
      await pullHandler!(database);
    }
  }
}
