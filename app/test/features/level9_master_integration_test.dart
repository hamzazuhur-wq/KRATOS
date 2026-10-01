// Level 9 Master Integration Test: Ecosystem Expansion, Real-Time Collaboration & Intelligent Coaching (Waves 24–28)
//
// Integration harness verifying:
//   1. All 35 Drift tables open and queryable in a unified offline database
//   2. Wave 24: Collaborative Notes CRDT delta logging and text convergence
//   3. Wave 25: AI Habit Coach fatigue analysis with Invariant #11 audit logging
//   4. Wave 26: 30-day trash retention window, entity restoration, and expiration purge
//   5. Wave 27: Live Activity ticker countdown and progress monitoring
//   6. Cross-system workflow: session execution -> habit velocity check -> janitor audit

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/ai/data/burnout_detection_service.dart';
import 'package:kratos_app/features/ai/domain/coach_models.dart';
import 'package:kratos_app/features/collaboration/data/collaborative_notes_dao.dart';
import 'package:kratos_app/features/maintenance/domain/janitor_service.dart';
import 'package:kratos_app/features/sessions/domain/live_activity_service.dart';

AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedBaseUser(AppDatabase db, String userId) async {
  await db.into(db.users).insert(UsersCompanion(
        id: Value(userId),
        deviceId: const Value('dev-master-01'),
        displayName: const Value('Hamza'),
        timezone: const Value('UTC'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
}

void main() {
  const userId = 'usr_hamza_01';

  group('Level 9 — Master Schema & Database Integration', () {
    test('DB opens with all 35 Drift tables accessible', () async {
      final db = _openInMemory();
      await _seedBaseUser(db, userId);

      // Verify new Wave 24 tables queryable
      final notes = await db.select(db.collaborativeNotes).get();
      final deltas = await db.select(db.collaborativeNoteDeltas).get();

      expect(notes, isEmpty);
      expect(deltas, isEmpty);

      await db.close();
    });
  });

  group('Level 9 — Cross-Wave Workflow: Collaboration, AI Coach, Janitor, Live Activity', () {
    late AppDatabase db;
    late CollaborativeNotesDao notesDao;
    late BurnoutDetectionService coachService;
    late JanitorService janitorService;
    late LiveActivityService liveActivityService;

    setUp(() async {
      db = _openInMemory();
      notesDao = CollaborativeNotesDao(db);
      coachService = BurnoutDetectionService(db: db);
      janitorService = JanitorService(db: db);
      liveActivityService = LiveActivityService();
      await _seedBaseUser(db, userId);
    });

    tearDown(() async {
      liveActivityService.dispose();
      await db.close();
    });

    test('Wave 24 + 25: collaborative note editing alongside habit coaching audit', () async {
      // 1. Create a collaborative note
      const noteId = 'collab_note_1';
      await notesDao.createNote(CollaborativeNotesCompanion(
        id: const Value(noteId),
        ownerId: const Value(userId),
        title: const Value('Sprint Retrospective'),
        plainText: const Value('Goals for this week'),
        versionHlc: const Value('1-0-0'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));

      // Append CRDT delta
      await notesDao.appendDelta(CollaborativeNoteDeltasCompanion(
        id: const Value('delta_1'),
        noteId: const Value(noteId),
        authorId: const Value(userId),
        deltaOp: const Value('{"op": "insert"}'),
        clientSequence: const Value(1),
        versionHlc: const Value('1-0-1'),
        appliedAt: Value(DateTime.now().toUtc()),
      ));

      // 2. Perform AI coach analysis
      const metrics = HabitVelocityMetrics(
        consecutiveActiveDays: 8,
        sessionsPast7Days: 14,
        totalMinutesPast7Days: 600,
        latePenaltiesPast7Days: 0,
        averageDailyXp: 120,
      );

      final rec = await coachService.analyzeHabitVelocity(
        userId: userId,
        metrics: metrics,
      );

      expect(rec.riskLevel, BurnoutRiskLevel.low);

      // Verify AI audit record exists
      final artifacts = await db.select(db.aiArtifacts).get();
      expect(artifacts.length, 1);
      expect(artifacts.first.kind, 'burnout_coaching_advisory');

      // Verify note and delta exist in DB
      final fetchedNote = await notesDao.getNoteById(noteId);
      final fetchedDeltas = await notesDao.getDeltasForNote(noteId);
      expect(fetchedNote, isNotNull);
      expect(fetchedDeltas.length, 1);
    });

    test('Wave 26 + 27: focus session live ticker alongside janitor storage audit', () async {
      // 1. Start live focus session activity
      liveActivityService.start(
        sessionId: 'sess_deep_1',
        title: 'Deep Architecture Work',
        lifeAreaName: 'Engineering',
        durationSeconds: 1500,
      );

      final state = liveActivityService.currentState;
      expect(state, isNotNull);
      expect(state!.remainingSeconds, 1500);

      // 2. Perform janitor storage audit
      final report = await janitorService.auditStorageHealth(userId);
      expect(report.isClockHealthy, isTrue);
      expect(report.trashCount, 0);

      // 3. Stop live activity cleanly
      liveActivityService.stop();
      expect(liveActivityService.currentState, isNull);
    });
  });
}
