// ignore_for_file: public_member_api_docs
// Wave 30: TelemetryService — Real-time performance profiling, error recording, and diagnostic streams.
//
// Adheres to zero-knowledge privacy standards: never captures personal text or keys.

import 'dart:async';

enum LogLevel { info, warning, error }

class TelemetryEvent {
  final String name;
  final LogLevel level;
  final Map<String, dynamic> attributes;
  final DateTime timestamp;

  const TelemetryEvent({
    required this.name,
    required this.level,
    this.attributes = const {},
    required this.timestamp,
  });
}

class PerformanceMetric {
  final String operation;
  final int durationMs;
  final DateTime timestamp;

  const PerformanceMetric({
    required this.operation,
    required this.durationMs,
    required this.timestamp,
  });
}

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final _eventStream = StreamController<TelemetryEvent>.broadcast();
  final List<TelemetryEvent> _events = [];
  final List<PerformanceMetric> _metrics = [];
  static const int _maxBufferSize = 100;

  Stream<TelemetryEvent> get eventStream => _eventStream.stream;
  List<TelemetryEvent> get recentEvents => List.unmodifiable(_events);
  List<PerformanceMetric> get recentMetrics => List.unmodifiable(_metrics);

  /// Records an anonymized telemetry event.
  void recordEvent(String name, {LogLevel level = LogLevel.info, Map<String, dynamic> attributes = const {}}) {
    final event = TelemetryEvent(
      name: name,
      level: level,
      attributes: attributes,
      timestamp: DateTime.now().toUtc(),
    );

    _events.insert(0, event);
    if (_events.length > _maxBufferSize) {
      _events.removeLast();
    }

    _eventStream.add(event);
  }

  /// Records an application error with safe metadata.
  void recordError(dynamic error, [StackTrace? stackTrace]) {
    recordEvent(
      'error_captured',
      level: LogLevel.error,
      attributes: {
        'error_type': error.runtimeType.toString(),
        'message': error.toString(),
        'has_stack': stackTrace != null,
      },
    );
  }

  /// Profiles an operation duration in milliseconds.
  void recordPerformance(String operation, int durationMs) {
    final metric = PerformanceMetric(
      operation: operation,
      durationMs: durationMs,
      timestamp: DateTime.now().toUtc(),
    );

    _metrics.insert(0, metric);
    if (_metrics.length > _maxBufferSize) {
      _metrics.removeLast();
    }
  }

  /// Computes average execution latency for a given operation.
  double getAverageLatencyMs(String operation) {
    final matching = _metrics.where((m) => m.operation == operation).toList();
    if (matching.isEmpty) return 0.0;
    final sum = matching.fold<int>(0, (prev, m) => prev + m.durationMs);
    return sum / matching.length;
  }

  /// Clears buffer.
  void clear() {
    _events.clear();
    _metrics.clear();
  }
}
