// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import '../../../data/drift/app_database.dart';
import 'sync_models.dart';

class SyncEngine {
  final SyncOutboxStore _outbox;
  final SyncTransport _transport;
  final String _userId;
  final String _deviceId;
  final AppDatabase? _database;

  final _stateController = StreamController<SyncConnectionState>.broadcast();
  SyncConnectionState _currentState = SyncConnectionState.offline;
  Timer? _drainTimer;
  bool _isDraining = false;
  bool _isPulling = false;

  SyncEngine({
    required SyncOutboxStore outbox,
    required SyncTransport transport,
    required String userId,
    required String deviceId,
    AppDatabase? database,
  }) : _outbox = outbox,
       _transport = transport,
       _userId = userId,
       _deviceId = deviceId,
       _database = database;

  Stream<SyncConnectionState> get stateStream => _stateController.stream;
  SyncConnectionState get currentState => _currentState;

  void start({Duration interval = const Duration(seconds: 15)}) {
    _drainTimer?.cancel();
    _runSyncCycle();
    _drainTimer = Timer.periodic(interval, (_) => _runSyncCycle());
  }

  Future<void> _runSyncCycle() async {
    final pending = await _outbox.countPending(_userId);
    if (pending > 0) {
      await triggerDrain();
    }
    final db = _database;
    if (db != null) {
      final stillPending = await _outbox.countPending(_userId);
      if (stillPending == 0) {
        await triggerPull(db);
      }
    }
  }

  void stop() {
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  /// Initial hydration (bootstrap after login).
  /// Pulls remote snapshot from Supabase into Drift and updates the watermark cursor.
  Future<void> initialHydration(AppDatabase database) async {
    if (_isPulling) return;
    _isPulling = true;
    _setState(SyncConnectionState.syncing);
    try {
      await _transport.pullChanges(
        userId: _userId,
        deviceId: _deviceId,
        database: database,
      );
      _setState(SyncConnectionState.online);
    } catch (e) {
      _setState(SyncConnectionState.error);
      rethrow;
    } finally {
      _isPulling = false;
    }
  }

  /// Unified bidirectional sync cycle: pushes pending outbox, then pulls remote changes.
  Future<SyncResult> sync({bool forcePull = false}) async {
    if (_isDraining || _isPulling) {
      return SyncResult.failure('A sync operation is already in progress.');
    }

    final pendingCount = await _outbox.countPending(_userId);
    SyncResult result;
    if (pendingCount > 0) {
      result = await triggerDrain();
      if (!result.isSuccess && !forcePull) {
        return result;
      }
    } else {
      result = const SyncResult(applied: 0, skipped: 0, isSuccess: true);
      _setState(SyncConnectionState.online);
    }

    final db = _database;
    if (db != null) {
      await triggerPull(db);
    }
    return result;
  }

  Future<void> triggerPull([AppDatabase? database]) async {
    final db = database ?? _database;
    if (db == null || _isPulling) return;
    _isPulling = true;
    try {
      await _transport.pullChanges(
        userId: _userId,
        deviceId: _deviceId,
        database: db,
      );
      _setState(SyncConnectionState.online);
    } catch (_) {
      // Background pull failures (network/offline) do not interrupt the engine
    } finally {
      _isPulling = false;
    }
  }

  Future<SyncResult> triggerDrain() async {
    if (_isDraining) {
      return SyncResult.failure('A sync batch is already in progress.');
    }
    _isDraining = true;
    _setState(SyncConnectionState.syncing);
    var attemptedItems = <SyncItem>[];
    try {
      final items = await _outbox.loadPending(_userId, limit: 50);
      if (items.isEmpty) {
        if (await _outbox.countPending(_userId) > 0) {
          _setState(SyncConnectionState.error);
          return SyncResult.failure(
            'Pending operations are waiting for their retry time.',
          );
        }
        _setState(SyncConnectionState.offline);
        return SyncResult.failure(
          'No operation was sent; server acknowledgement is unavailable.',
        );
      }

      attemptedItems = items;

      final acknowledgements = await _transport.pushBatch(
        userId: _userId,
        deviceId: _deviceId,
        items: items,
      );
      final expectedSeqs = items.map((item) => item.seq).toSet();
      final acknowledgedSet = acknowledgements.map((item) => item.seq).toSet();
      if (acknowledgedSet.length != acknowledgements.length ||
          acknowledgedSet.length != expectedSeqs.length ||
          !acknowledgedSet.containsAll(expectedSeqs) ||
          acknowledgements.any(
            (item) =>
                !{'applied', 'skipped', 'duplicate'}.contains(item.status),
          )) {
        throw const SyncTransportException(
          message:
              'The server acknowledgement did not cover the submitted batch.',
          code: 'incomplete_acknowledgement',
          retryable: true,
        );
      }
      final acknowledgedSeqs = acknowledgements.map((a) => a.seq).toList();
      await _outbox.markAcknowledged(acknowledgedSeqs);
      _setState(SyncConnectionState.online);
      return SyncResult(
        applied: acknowledgements.where((a) => a.status == 'applied').length,
        skipped: acknowledgements
            .where((a) => a.status == 'skipped' || a.status == 'duplicate')
            .length,
      );
    } catch (error) {
      final failure = error is SyncTransportException
          ? error
          : SyncTransportException(
              message: error.toString(),
              code: 'transport_error',
              retryable: true,
            );
      for (final item in attemptedItems) {
        await _outbox.recordFailure(
          seq: item.seq,
          errorClass: failure.retryable ? 'retryable' : 'permanent',
          errorCode: failure.code,
          backoff: calculateBackoff(item.attempts + 1),
          retryable: failure.retryable,
        );
      }
      _setState(SyncConnectionState.error);
      return SyncResult.failure(failure.toString());
    } finally {
      _isDraining = false;
    }
  }

  Duration calculateBackoff(int attempt) {
    final seconds = min(pow(2, attempt).toInt(), 300);
    return Duration(seconds: seconds);
  }

  void _setState(SyncConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
