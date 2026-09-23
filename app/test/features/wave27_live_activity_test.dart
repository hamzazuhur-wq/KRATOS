// Wave 27 Unit Tests: Live Activities & System Widgets Engine
//
// Tests cover:
//   1. LiveSessionState remaining seconds calculation and boundary clamps
//   2. Progress percentage computation
//   3. LiveActivityService start & broadcast
//   4. Pause and resume state transitions
//   5. Stop and clean shutdown

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/sessions/domain/live_activity_service.dart';

void main() {
  group('LiveSessionState', () {
    test('remainingSeconds and progressPct compute accurately', () {
      final state = LiveSessionState(
        sessionId: 'sess_1',
        title: 'Deep Coding',
        lifeAreaName: 'Career',
        startedAt: DateTime.now().toUtc(),
        plannedDurationSeconds: 1500, // 25 minutes
        elapsedSeconds: 300,          // 5 minutes
        isPaused: false,
      );

      expect(state.remainingSeconds, 1200);
      expect(state.progressPct, closeTo(0.2, 0.001));
      expect(state.isCompleted, isFalse);
    });

    test('remainingSeconds clamps at zero when elapsed exceeds planned', () {
      final state = LiveSessionState(
        sessionId: 'sess_2',
        title: 'Sprint Overtime',
        startedAt: DateTime.now().toUtc(),
        plannedDurationSeconds: 600,
        elapsedSeconds: 700,
        isPaused: false,
      );

      expect(state.remainingSeconds, 0);
      expect(state.progressPct, 1.0);
      expect(state.isCompleted, isTrue);
    });
  });

  group('LiveActivityService', () {
    late LiveActivityService service;

    setUp(() {
      service = LiveActivityService();
    });

    tearDown(() {
      service.dispose();
    });

    test('start emits valid LiveSessionState', () async {
      service.start(
        sessionId: 'sess_live',
        title: 'Reading',
        lifeAreaName: 'Mind',
        durationSeconds: 600,
      );

      final state = service.currentState;
      expect(state, isNotNull);
      expect(state!.title, 'Reading');
      expect(state.plannedDurationSeconds, 600);
      expect(state.isPaused, isFalse);
    });

    test('pause and resume modify state correctly', () {
      service.start(
        sessionId: 'sess_pause_test',
        title: 'Workout',
        durationSeconds: 1800,
      );

      service.pause();
      expect(service.currentState!.isPaused, isTrue);

      service.resume();
      expect(service.currentState!.isPaused, isFalse);
    });

    test('stop clears current state and emits null', () {
      service.start(
        sessionId: 'sess_stop_test',
        title: 'Meditation',
        durationSeconds: 600,
      );

      service.stop();
      expect(service.currentState, isNull);
    });
  });
}
