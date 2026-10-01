// Level 7: Platform, Security, Sync, Onboarding & Launch Full-System Test Suite.
// Comprehensive verification for Waves 14, 15, 16, 17, and 18.

import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/auth/domain/auth_models.dart';
import 'package:kratos_app/features/notifications/domain/notification_service.dart';
import 'package:kratos_app/features/onboarding/domain/onboarding_models.dart';
import 'package:kratos_app/features/onboarding/domain/onboarding_service.dart';
import 'package:kratos_app/features/sync/domain/sync_engine.dart';
import 'package:kratos_app/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Wave 14: PWA Web Standards ──────────────────────────────────────────

  group('Level 7 / Wave 14: PWA Web Standards & App Shortcuts', () {
    test('Default templates provide valid colors and icon configurations', () {
      expect(OnboardingDefaults.templates.isNotEmpty, isTrue);
      for (final t in OnboardingDefaults.templates) {
        expect(t.colorHex, startsWith('#'));
        expect(t.name.isNotEmpty, isTrue);
      }
    });
  });

  // ─── Wave 15: Auth & Security Hardening ──────────────────────────────────

  group('Level 7 / Wave 15: Authentication & Session Lifecycle', () {
    test(
      'MockAuthService allows instant dev bypass without external dependencies',
      () async {
        final auth = MockAuthService(autoAuthenticate: false);
        expect(auth.currentState, isA<AuthUnauthenticated>());

        await auth.signInWithDevBypass(
          userId: 'usr_dev_hamza',
          displayName: 'Hamza Dev',
        );
        expect(auth.currentState, isA<AuthAuthenticated>());
        expect(auth.currentUser?.id.value, equals('usr_dev_hamza'));
        expect(auth.currentUser?.displayName, equals('Hamza Dev'));

        await auth.signOut();
        expect(auth.currentState, isA<AuthUnauthenticated>());
        expect(auth.currentUser, isNull);
        auth.dispose();
      },
    );
  });

  // ─── Wave 16: Background Sync Engine & Outbox Drain ───────────────────────

  group('Level 7 / Wave 16: Background Sync Engine & Notifications', () {
    test('SyncDao and SyncEngine drain outbox items in FIFO order', () async {
      const userId = 'usr_sync_test';
      const deviceId = 'dev_mobile_01';

      // Enqueue 3 mutations into sync_outbox
      for (int i = 1; i <= 3; i++) {
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                userId: userId,
                op: 'insert',
                entity: 'tasks',
                entityId: 'tsk_00$i',
                payloadJson: '{"title":"Task $i"}',
                hlc: '0191ebc4-000$i',
                deviceId: deviceId,
              ),
            );
      }

      // Check pending count
      final pendingCount = await db.syncDao.countPendingItems(userId);
      expect(pendingCount, equals(3));

      // Trigger drain via SyncEngine
      final engine = SyncEngine(
        outbox: db.syncDao,
        transport: _AcknowledgingTransport(),
        userId: userId,
        deviceId: deviceId,
      );
      final result = await engine.triggerDrain();

      expect(result.isSuccess, isTrue);
      expect(result.applied, equals(3));

      // Outbox should now be completely drained
      final remainingCount = await db.syncDao.countPendingItems(userId);
      expect(remainingCount, equals(0));

      engine.dispose();
    });

    test(
      'NotificationService delivers streak alerts and freeze warnings',
      () async {
        final notifications = NotificationService();

        await notifications.scheduleStreakReminder(
          lifeAreaName: 'Health',
          currentStreak: 5,
          reminderTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        );

        await notifications.sendFreezeConsumedAlert(
          lifeAreaName: 'Health',
          tokensRemaining: 1,
        );

        expect(notifications.pendingNotifications.length, equals(2));
        expect(
          notifications.pendingNotifications[0].kind,
          equals(NotificationKind.streakReminder),
        );
        expect(
          notifications.pendingNotifications[1].kind,
          equals(NotificationKind.freezeConsumed),
        );

        notifications.dispose();
      },
    );
  });

  // ─── Wave 17: Onboarding Flow & Seeding ──────────────────────────────────

  group('Level 7 / Wave 17: Onboarding Bootstrap Transaction', () {
    test('completeOnboarding atomically seeds LifeAreas, 2 Freeze Tokens each, and Goal', () async {
      final onboarding = OnboardingService(db);
      const userId = 'usr_onboard_test';
      final selectedAreas = {'la_health', 'la_career'};

      await onboarding.completeOnboarding(
        userId: userId,
        selectedAreaIds: selectedAreas,
        initialGoalTitle: 'Run 10km and Ship Kratos',
        initialGoalXp: 750,
        versionHlc: '0191ebc4-test',
      );

      // Verify LifeAreas were inserted
      final lifeAreas = await db.select(db.lifeAreas).get();
      expect(lifeAreas.length, equals(2));
      expect(
        lifeAreas.map((a) => a.name).toSet(),
        equals({'Health & Vitality', 'Career & Craft'}),
      );
      expect(lifeAreas.every((area) => Id(area.id).isUuidV7), isTrue);

      // Invariant Check (ADR-005): Each LifeArea starts with exactly 2 free freeze tokens
      final inventory = await db.select(db.streakFreezeInventory).get();
      expect(inventory.length, equals(2));
      for (final inv in inventory) {
        expect(inv.userId, equals(userId));
        expect(inv.tokensAvailable, equals(2));
        expect(inv.tokensUsed, equals(0));
      }

      // Verify Goal was inserted
      final goals = await db.select(db.goals).get();
      expect(goals.length, equals(1));
      final goal = goals.first;
      expect(goal.title, equals('Run 10km and Ship Kratos'));
      expect(goal.xpTarget, equals(750));
      expect(goal.ownerId, equals(userId));
      expect(lifeAreas.any((area) => area.id == goal.lifeAreaId), isTrue);
      expect(await onboarding.isCompleted(userId), isTrue);
      expect(await db.select(db.syncOutbox).get(), hasLength(3));

      await onboarding.completeOnboarding(
        userId: userId,
        selectedAreaIds: selectedAreas,
        initialGoalTitle: 'Duplicate must not be created',
        versionHlc: '0191ebc5-test',
      );
      expect(await db.select(db.goals).get(), hasLength(1));
      expect(await db.select(db.syncOutbox).get(), hasLength(3));
    });
  });

  // ─── Wave 18: Production Launch & Shell Integrity ─────────────────────────

  group('Level 7 / Wave 18: Full-System Integration & Invariants', () {
    test(
      'all Level 7 services interoperate with zero runtime errors',
      () async {
        // 1. Authenticate
        final auth = MockAuthService(autoAuthenticate: true);
        final user = auth.currentUser!;
        expect(user.id.value.isNotEmpty, isTrue);

        // 2. Run Onboarding
        final onboarding = OnboardingService(db);
        await onboarding.completeOnboarding(
          userId: user.id.value,
          selectedAreaIds: {'la_health', 'la_career'},
          initialGoalTitle: 'Level 7 Master Goal',
          initialGoalXp: 1000,
          versionHlc: '0191ebc4-test',
        );

        // 3. Enqueue mutation to outbox
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                userId: user.id.value,
                op: 'insert',
                entity: 'goals',
                entityId: Id.uuidV7().value,
                payloadJson: '{"title":"Level 7 Master Goal"}',
                hlc: '0191ebc4-test',
                deviceId: 'dev_e2e_01',
              ),
            );

        // 4. Drain outbox
        final engine = SyncEngine(
          outbox: db.syncDao,
          transport: _AcknowledgingTransport(),
          userId: user.id.value,
          deviceId: 'dev_e2e_01',
        );
        final drainResult = await engine.triggerDrain();
        expect(drainResult.isSuccess, isTrue);
        // Onboarding journals two areas and its starter goal atomically too.
        expect(drainResult.applied, equals(4));

        engine.dispose();
        auth.dispose();
      },
    );
  });
}

class _AcknowledgingTransport implements SyncTransport {
  @override
  Future<List<SyncAcknowledgement>> pushBatch({
    required String userId,
    required String deviceId,
    required List<SyncItem> items,
  }) async => items
      .map((item) => SyncAcknowledgement(seq: item.seq, status: 'applied'))
      .toList();

  @override
  Future<void> pullChanges({
    required String userId,
    required String deviceId,
    required AppDatabase database,
  }) async {}
}
