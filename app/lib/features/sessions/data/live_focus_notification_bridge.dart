// ignore_for_file: public_member_api_docs

import 'package:flutter/services.dart';

class LiveFocusNotificationBridge {
  static const _channel = MethodChannel('com.hamza.kratos/focus_session');
  static bool _initialized = false;

  static void Function()? onNativePause;
  static void Function()? onNativeResume;
  static void Function()? onNativeComplete;
  static void Function()? onNativeStop;

  static void initCallbacks() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNativePause':
          onNativePause?.call();
        case 'onNativeResume':
          onNativeResume?.call();
        case 'onNativeComplete':
          onNativeComplete?.call();
        case 'onNativeStop':
          onNativeStop?.call();
      }
    });
  }

  /// Starts the Android/Samsung live stopwatch & notification pill / iOS Live Activity.
  static Future<void> start({
    required String sessionId,
    required String title,
    String? lifeAreaName,
    int? targetSeconds,
  }) async {
    initCallbacks();
    try {
      await _channel.invokeMethod('startFocusSession', {
        'sessionId': sessionId,
        'title': title,
        'lifeAreaName': lifeAreaName ?? '',
        'targetSeconds': targetSeconds ?? 0,
        'startedAtTimestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      // Gracefully ignored on platforms without the native channel (e.g. Web)
    }
  }

  /// Pauses the live notification / stopwatch pill.
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pauseFocusSession');
    } catch (_) {}
  }

  /// Resumes the live notification / stopwatch pill.
  static Future<void> resume() async {
    try {
      await _channel.invokeMethod('resumeFocusSession');
    } catch (_) {}
  }

  /// Stops and dismisses the live notification / stopwatch pill.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopFocusSession');
    } catch (_) {}
  }
}
