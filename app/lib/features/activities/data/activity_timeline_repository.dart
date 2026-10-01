import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';

/// Repository for querying and filtering the append-only Activity Timeline (Phase 7).
/// Supports chronological ordering (newest first), time ranges, life area filtering,
/// entity filtering, and pagination.
class ActivityTimelineRepository {
  final AppDatabase database;

  ActivityTimelineRepository({required this.database});

  /// Fetches activity events matching criteria ordered newest first.
  Future<List<ActivityEvent>> fetchTimeline({
    required String ownerId,
    String? lifeAreaId,
    String? eventType,
    String? entityType,
    String? entityId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) {
    final query = database.select(database.activityEvents)
      ..where((e) {
        Expression<bool> predicate = e.ownerId.equals(ownerId);
        if (lifeAreaId != null) {
          predicate = predicate & e.lifeAreaId.equals(lifeAreaId);
        }
        if (eventType != null) {
          predicate = predicate & e.eventType.equals(eventType);
        }
        if (entityType != null) {
          predicate = predicate & e.entityType.equals(entityType);
        }
        if (entityId != null) {
          predicate = predicate & e.entityId.equals(entityId);
        }
        if (startDate != null) {
          predicate = predicate & e.occurredAt.isBiggerOrEqualValue(startDate);
        }
        if (endDate != null) {
          predicate = predicate & e.occurredAt.isSmallerOrEqualValue(endDate);
        }
        return predicate;
      })
      ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
      ..limit(limit, offset: offset);

    return query.get();
  }

  /// Reactive stream of activity events for live timeline UI updates.
  Stream<List<ActivityEvent>> watchTimeline({
    required String ownerId,
    String? lifeAreaId,
    String? eventType,
    String? entityType,
    int limit = 50,
  }) {
    final query = database.select(database.activityEvents)
      ..where((e) {
        Expression<bool> predicate = e.ownerId.equals(ownerId);
        if (lifeAreaId != null) {
          predicate = predicate & e.lifeAreaId.equals(lifeAreaId);
        }
        if (eventType != null) {
          predicate = predicate & e.eventType.equals(eventType);
        }
        if (entityType != null) {
          predicate = predicate & e.entityType.equals(entityType);
        }
        return predicate;
      })
      ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
      ..limit(limit);

    return query.watch();
  }
}
