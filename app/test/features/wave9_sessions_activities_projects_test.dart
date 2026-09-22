// Wave 9: Unit tests for Session, Activity, and Project domain entities.

import 'package:test/test.dart';

import '../../lib/domain/errors.dart';
import '../../lib/domain/hlc.dart';
import '../../lib/domain/ids.dart';
import '../../lib/domain/timestamps.dart';
import '../../lib/features/sessions/domain/session_models.dart';

void main() {
  Hlc hlc([int c = 1]) => Hlc(
        wallMs: DateTime.now().millisecondsSinceEpoch,
        counter: c,
        node: 'test',
      );

  Iso8601Timestamp now() => Iso8601Timestamp.now();

  // ─── ActivityXpRule Tests ──────────────────────────────────────────────

  group('ActivityXpRule', () {
    test('per-minute XP computes correctly', () {
      const rule = ActivityXpRule(perMinuteXp: 5);
      // 30 min = 1,800,000 ms → 150 XP
      expect(rule.computeXp(1800000), equals(150));
    });

    test('flat XP returns fixed value regardless of duration', () {
      const rule = ActivityXpRule(flatXp: 80);
      expect(rule.computeXp(0), equals(80));
      expect(rule.computeXp(3600000), equals(80));
    });

    test('per-minute takes precedence when both set', () {
      const rule = ActivityXpRule(perMinuteXp: 3, flatXp: 100);
      // 10 min → 30 XP (not 100)
      expect(rule.computeXp(600000), equals(30));
    });

    test('roundtrips through JSON', () {
      const rule = ActivityXpRule(perMinuteXp: 4, flatXp: 50);
      final json = rule.toJson();
      final restored = ActivityXpRule.fromJson(json);
      expect(restored.perMinuteXp, equals(4));
      expect(restored.flatXp, equals(50));
    });
  });

  // ─── ActivityEntity Tests ──────────────────────────────────────────────

  group('ActivityEntity', () {
    ActivityEntity makeActivity() => ActivityEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          name: 'Morning Run',
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
          xpRule: const ActivityXpRule(perMinuteXp: 3),
        );

    test('creates valid activity', () {
      final a = makeActivity();
      expect(a.name, equals('Morning Run'));
      expect(a.isActive, isTrue);
    });

    test('rejects blank name', () {
      expect(
        () => ActivityEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          name: '  ',
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rename returns new instance', () {
      final a = makeActivity();
      final renamed = a.rename('Evening Run', hlc(2));
      expect(renamed.name, equals('Evening Run'));
      expect(renamed.id, equals(a.id));
    });
  });

  // ─── SessionEntity Tests ───────────────────────────────────────────────

  group('SessionEntity', () {
    SessionEntity makeSession({bool withActivity = true}) => SessionEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          activityId: withActivity ? Id.uuidV7() : null,
          taskId: withActivity ? null : Id.uuidV7(),
          startedAt: now(),
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        );

    test('creates valid running session with activity', () {
      final s = makeSession();
      expect(s.isRunning, isTrue);
      expect(s.isCompleted, isFalse);
    });

    test('creates valid running session with task', () {
      final s = makeSession(withActivity: false);
      expect(s.isRunning, isTrue);
    });

    test('rejects session with no task or activity', () {
      expect(
        () => SessionEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          startedAt: now(),
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rejects negative durationMs', () {
      expect(
        () => SessionEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          activityId: Id.uuidV7(),
          startedAt: now(),
          durationMs: -1,
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('end() transitions to completed with correct durationMs', () {
      final start = DateTime.now().toUtc();
      final s = SessionEntity(
        id: Id.uuidV7(),
        ownerId: Id.uuidV7(),
        activityId: Id.uuidV7(),
        startedAt: Iso8601Timestamp(start),
        versionHlc: hlc(),
        createdAt: Iso8601Timestamp(start),
        updatedAt: Iso8601Timestamp(start),
      );
      final endTime =
          Iso8601Timestamp(start.add(const Duration(minutes: 30)));
      final ended = s.end(endTime, hlc(2));
      expect(ended.isCompleted, isTrue);
      expect(ended.durationMs, equals(30 * 60 * 1000));
    });

    test('end() throws on already-completed session', () {
      final start = DateTime.now().toUtc();
      final s = SessionEntity(
        id: Id.uuidV7(),
        ownerId: Id.uuidV7(),
        activityId: Id.uuidV7(),
        startedAt: Iso8601Timestamp(start),
        endedAt: Iso8601Timestamp(start.add(const Duration(minutes: 10))),
        durationMs: 600000,
        versionHlc: hlc(),
        createdAt: Iso8601Timestamp(start),
        updatedAt: Iso8601Timestamp(start),
      );
      expect(
        () => s.end(Iso8601Timestamp(start.add(const Duration(minutes: 20))),
            hlc(2)),
        throwsA(isA<ConflictError>()),
      );
    });

    test('formattedDuration formats correctly', () {
      final start = DateTime.now().toUtc();
      final s = SessionEntity(
        id: Id.uuidV7(),
        ownerId: Id.uuidV7(),
        activityId: Id.uuidV7(),
        startedAt: Iso8601Timestamp(start),
        endedAt: Iso8601Timestamp(
            start.add(const Duration(hours: 1, minutes: 23))),
        durationMs: (1 * 60 + 23) * 60 * 1000,
        versionHlc: hlc(),
        createdAt: Iso8601Timestamp(start),
        updatedAt: Iso8601Timestamp(start),
      );
      expect(s.formattedDuration, equals('1h 23m'));
    });
  });

  // ─── ProjectEntity Tests ───────────────────────────────────────────────

  group('ProjectEntity', () {
    ProjectEntity makeProject() => ProjectEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          title: 'KRATOS MVP',
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        );

    test('creates active project', () {
      final p = makeProject();
      expect(p.isActive, isTrue);
      expect(p.status, equals(ProjectStatus.active));
    });

    test('rejects blank title', () {
      expect(
        () => ProjectEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          title: '',
          versionHlc: hlc(),
          createdAt: now(),
          updatedAt: now(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('complete() transitions status', () {
      final p = makeProject();
      final completed = p.complete(hlc(2));
      expect(completed.isCompleted, isTrue);
    });

    test('complete() twice throws ConflictError', () {
      final p = makeProject().complete(hlc(2));
      expect(() => p.complete(hlc(3)), throwsA(isA<ConflictError>()));
    });

    test('rename() returns new project with updated title', () {
      final p = makeProject();
      final renamed = p.rename('KRATOS 2.0', hlc(2));
      expect(renamed.title, equals('KRATOS 2.0'));
      expect(renamed.id, equals(p.id));
    });

    test('rename() on completed project throws ConflictError', () {
      final p = makeProject().complete(hlc(2));
      expect(() => p.rename('New Name', hlc(3)), throwsA(isA<ConflictError>()));
    });
  });
}
