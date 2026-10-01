// ignore_for_file: public_member_api_docs

import '../data/local_notifications_service.dart';
import 'system_notification_bridge.dart';

/// Native (mobile/desktop) implementation: delivers real OS notifications
/// through `flutter_local_notifications`.
class SystemNotificationBridgeImpl implements SystemNotificationBridge {
  int _seq = 0;

  @override
  Future<String> requestPermission() async {
    final service = LocalNotificationsService.instance;
    await service.initialize();
    return service.requestPermission();
  }

  @override
  String getPermission() => LocalNotificationsService.instance.permission;

  @override
  bool showNotification(String title, String body) {
    final service = LocalNotificationsService.instance;
    // Fire-and-forget: the UI must never block on a notification delivery.
    unawaited(
      service.show(
        id: LocalNotificationsService.notificationIdFor('$title|$body|${_seq++}'),
        title: title,
        body: body,
      ),
    );
    return true;
  }
}

void unawaited(Future<void> future) {
  future.catchError((Object error) {
    // Swallow: notifications are best-effort.
  });
}

SystemNotificationBridge createSystemNotificationBridge() =>
    SystemNotificationBridgeImpl();
