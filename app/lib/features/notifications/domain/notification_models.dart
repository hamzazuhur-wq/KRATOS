import 'dart:convert';
import 'notification_service.dart';

enum NotificationSeverity {
  urgent,
  warning,
  info,
}

/// Unified model for persisted KRATOS notifications (Phase 7).
class NotificationRecord {
  final String id;
  final String ownerId;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final String? activityEventId;
  final NotificationSeverity severity;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final Map<String, dynamic> metadata;
  final String versionHlc;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationRecord({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.activityEventId,
    this.severity = NotificationSeverity.info,
    this.readAt,
    this.dismissedAt,
    this.metadata = const {},
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRead => readAt != null;
  bool get isDismissed => dismissedAt != null;

  NotificationRecord copyWith({
    String? title,
    String? body,
    NotificationSeverity? severity,
    DateTime? readAt,
    DateTime? dismissedAt,
    Map<String, dynamic>? metadata,
    String? versionHlc,
    DateTime? updatedAt,
  }) {
    return NotificationRecord(
      id: id,
      ownerId: ownerId,
      type: type,
      title: title ?? this.title,
      body: body ?? this.body,
      entityType: entityType,
      entityId: entityId,
      activityEventId: activityEventId,
      severity: severity ?? this.severity,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      metadata: metadata ?? this.metadata,
      versionHlc: versionHlc ?? this.versionHlc,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'type': type,
      'title': title,
      'body': body,
      'entity_type': entityType,
      'entity_id': entityId,
      'activity_event_id': activityEventId,
      'severity': severity.name,
      'read_at': readAt?.toIso8601String(),
      'dismissed_at': dismissedAt?.toIso8601String(),
      'metadata': metadata,
      'version_hlc': versionHlc,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      activityEventId: json['activity_event_id'] as String?,
      severity: _parseSeverity(json['severity'] as String?),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      dismissedAt: json['dismissed_at'] != null ? DateTime.parse(json['dismissed_at'] as String) : null,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : (json['metadata'] is String ? jsonDecode(json['metadata'] as String) as Map<String, dynamic> : {}),
      versionHlc: json['version_hlc'] as String? ?? '0',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  static NotificationSeverity _parseSeverity(String? str) {
    switch (str?.toLowerCase()) {
      case 'urgent':
        return NotificationSeverity.urgent;
      case 'warning':
        return NotificationSeverity.warning;
      case 'info':
      default:
        return NotificationSeverity.info;
    }
  }

  KratosNotification toKratosNotification() {
    NotificationKind kind;
    switch (type) {
      case 'overdue':
        kind = NotificationKind.overdue;
        break;
      case 'ending_today':
        kind = NotificationKind.endingToday;
        break;
      case 'stale_paused':
        kind = NotificationKind.stalePaused;
        break;
      case 'level_up':
      case 'level_promoted':
        kind = NotificationKind.levelPromoted;
        break;
      case 'streak_milestone':
      case 'streak_reminder':
        kind = NotificationKind.streakReminder;
        break;
      case 'freeze_consumed':
        kind = NotificationKind.freezeConsumed;
        break;
      case 'achievement_unlocked':
      case 'weekly_bonus':
      default:
        kind = NotificationKind.weeklyBonusUnlocked;
        break;
    }

    return KratosNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      targetType: entityType,
      targetId: entityId,
      severity: severity,
      timestamp: createdAt,
      isRead: isRead,
      isDismissed: isDismissed,
      ownerId: ownerId,
      activityEventId: activityEventId,
      metadata: metadata,
      versionHlc: versionHlc,
    );
  }
}
