import '../ids.dart';

class ActivityEvent {
  final Id id;
  final Id ownerId;
  final String eventType;
  final String entityType;
  final Id? entityId;
  final Id? lifeAreaId;
  final Map<String, dynamic> metadata;
  final DateTime occurredAt;
  final String versionHlc;
  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.ownerId,
    required this.eventType,
    required this.entityType,
    this.entityId,
    this.lifeAreaId,
    this.metadata = const {},
    required this.occurredAt,
    required this.versionHlc,
    required this.createdAt,
  });
}
