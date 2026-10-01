// ignore_for_file: public_member_api_docs

import 'dart:js_interop';
import 'system_notification_bridge.dart';

@JS('kratosNotification.requestPermission')
external JSPromise<JSString> _jsRequestPermission();

@JS('kratosNotification.getPermission')
external JSString _jsGetPermission();

@JS('kratosNotification.show')
external JSBoolean _jsShow(JSString title, JSString body);

class SystemNotificationBridgeImpl implements SystemNotificationBridge {
  @override
  Future<String> requestPermission() async {
    try {
      final jsStr = await _jsRequestPermission().toDart;
      return jsStr.toDart;
    } catch (_) {
      return 'denied';
    }
  }

  @override
  String getPermission() {
    try {
      return _jsGetPermission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  @override
  bool showNotification(String title, String body) {
    try {
      return _jsShow(title.toJS, body.toJS).toDart;
    } catch (_) {
      return false;
    }
  }
}

SystemNotificationBridge createSystemNotificationBridge() => SystemNotificationBridgeImpl();
