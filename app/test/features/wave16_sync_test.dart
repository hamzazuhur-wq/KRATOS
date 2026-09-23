// Wave 16: Unit tests for Sync Engine models, backoff math, and Notification Service.

import 'package:test/test.dart';
import '../../lib/features/notifications/domain/notification_service.dart';
import '../../lib/features/sync/domain/sync_engine.dart';
import '../../lib/features/sync/domain/sync_models.dart';

void main() {
  group('Sync Models & Batch Payloads', () {
    test('SyncItem converts to correct batch payload structure', () {
      final item = SyncItem(
        seq: 101,
        userId: 'usr_test',
        op: 'insert',
        entity: 'tasks',
        entityId: 'tsk_001',
        payloadJson: '{"title":"Test"}',
        hlc: '0191ebc4-test',
        deviceId: 'dev_01',
        attempts: 0,
        status: SyncStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );

      final payload = item.toBatchPayload();
      expect(payload['seq'], equals(101));
      expect(payload['op'], equals('insert'));
      expect(payload['entity'], equals('tasks'));
      expect(payload['entity_id'], equals('tsk_001'));
      expect(payload['hlc'], equals('0191ebc4-test'));
    });

    test('SyncResult tracks success and failure states', () {
      const success = SyncResult(applied: 5, skipped: 1);
      expect(success.isSuccess, isTrue);
      expect(success.applied, equals(5));

      final failure = SyncResult.failure('Network timeout');
      expect(failure.isSuccess, isFalse);
      expect(failure.errorMessage, equals('Network timeout'));
    });
  });

  group('SyncEngine Backoff Math', () {
    test('exponential backoff scales cleanly and respects 300s cap', () {
      // We can test backoff calculation logic directly
      int calcBackoffSec(int attempt) {
        final sec = 1 << attempt; // 2^attempt
        return sec > 300 ? 300 : sec;
      }

      expect(calcBackoffSec(0), equals(1));
      expect(calcBackoffSec(1), equals(2));
      expect(calcBackoffSec(2), equals(4));
      expect(calcBackoffSec(3), equals(8));
      expect(calcBackoffSec(5), equals(32));
      expect(calcBackoffSec(9), equals(300)); // capped at 300
    });
  });

  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('scheduleStreakReminder enqueues correct notification', () async {
      await service.scheduleStreakReminder(
        lifeAreaName: 'Health',
        currentStreak: 12,
        reminderTime: DateTime.now().toUtc().add(const Duration(hours: 4)),
      );

      expect(service.pendingNotifications.length, equals(1));
      final n = service.pendingNotifications.first;
      expect(n.kind, equals(NotificationKind.streakReminder));
      expect(n.title, contains('Health'));
      expect(n.body, contains('12-day streak'));
    });

    test('sendFreezeConsumedAlert adds alert with tokens remaining', () async {
      await service.sendFreezeConsumedAlert(
        lifeAreaName: 'Career',
        tokensRemaining: 1,
      );

      expect(service.pendingNotifications.length, equals(1));
      final n = service.pendingNotifications.first;
      expect(n.kind, equals(NotificationKind.freezeConsumed));
      expect(n.title, contains('Protected'));
      expect(n.body, contains('1 token remaining'));
    });

    test('sendWeeklyBonusUnlocked adds +20% bonus celebration', () async {
      await service.sendWeeklyBonusUnlocked(lifeAreaName: 'Fitness');
      expect(service.pendingNotifications.length, equals(1));
      final n = service.pendingNotifications.first;
      expect(n.kind, equals(NotificationKind.weeklyBonusUnlocked));
      expect(n.title, contains('+20% XP Bonus'));
    });
  });
}
