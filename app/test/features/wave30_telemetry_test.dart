// Wave 30 Unit Tests: Telemetry, Error Reporting & Performance Profiling
//
// Tests cover:
//   1. Event recording and attribute mapping
//   2. Error recording with safe metadata
//   3. Performance metric latency averaging
//   4. Circular buffer size constraint (max 100 items)
//   5. Buffer reset and clean state

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/core/telemetry/telemetry_service.dart';

void main() {
  group('TelemetryService', () {
    late TelemetryService telemetry;

    setUp(() {
      telemetry = TelemetryService();
      telemetry.clear();
    });

    test('records events into recentEvents list', () {
      telemetry.recordEvent('app_startup', attributes: {'version': '1.0.0'});

      expect(telemetry.recentEvents.length, 1);
      expect(telemetry.recentEvents.first.name, 'app_startup');
      expect(telemetry.recentEvents.first.level, LogLevel.info);
      expect(telemetry.recentEvents.first.attributes['version'], '1.0.0');
    });

    test('records errors with error level', () {
      telemetry.recordError(Exception('Network timeout'));

      expect(telemetry.recentEvents.length, 1);
      expect(telemetry.recentEvents.first.level, LogLevel.error);
      expect(telemetry.recentEvents.first.attributes['message'], contains('Network timeout'));
    });

    test('calculates average latency accurately for performance profiling', () {
      telemetry.recordPerformance('db_query', 10);
      telemetry.recordPerformance('db_query', 20);
      telemetry.recordPerformance('db_query', 30);

      final avg = telemetry.getAverageLatencyMs('db_query');
      expect(avg, 20.0);
    });

    test('evicts oldest events when buffer exceeds max size of 100', () {
      for (var i = 0; i < 110; i++) {
        telemetry.recordEvent('event_$i');
      }

      expect(telemetry.recentEvents.length, 100);
      expect(telemetry.recentEvents.first.name, 'event_109');
    });

    test('clear() wipes all events and metrics', () {
      telemetry.recordEvent('e1');
      telemetry.recordPerformance('p1', 50);

      telemetry.clear();

      expect(telemetry.recentEvents, isEmpty);
      expect(telemetry.recentMetrics, isEmpty);
    });
  });
}
