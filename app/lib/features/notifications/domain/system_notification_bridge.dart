// ignore_for_file: public_member_api_docs

import 'system_notification_bridge_stub.dart'
    if (dart.library.js_interop) 'system_notification_bridge_web.dart';

abstract class SystemNotificationBridge {
  Future<String> requestPermission();
  String getPermission();
  bool showNotification(String title, String body);

  static final SystemNotificationBridge instance = createSystemNotificationBridge();
}
