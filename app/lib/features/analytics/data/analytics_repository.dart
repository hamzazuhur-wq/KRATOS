// Clean repository abstraction for KRATOS Analytics.
// Routes to DriftAnalyticsRepository when database is supplied,
// falling back to MockAnalyticsRepository strictly for detached tests.

import '../../../data/drift/app_database.dart';
import '../domain/analytics_models.dart';
import 'analytics_mock_data.dart';
import 'drift_analytics_repository.dart';

abstract class AnalyticsRepository {
  factory AnalyticsRepository([AppDatabase? database]) {
    if (database != null) {
      return DriftAnalyticsRepository(database);
    }
    return const MockAnalyticsRepository();
  }

  Future<List<({String id, String name})>> listLifeAreas(String ownerId);

  Future<AnalyticsSnapshot> load({
    required String ownerId,
    required AnalyticsDateRange range,
    String? lifeAreaId,
  });
}

/// Fallback mock repository preserved strictly for detached UI preview/tests.
class MockAnalyticsRepository implements AnalyticsRepository {
  const MockAnalyticsRepository();

  @override
  Future<List<({String id, String name})>> listLifeAreas(String ownerId) {
    return Future.value(AnalyticsMockData.lifeAreas);
  }

  @override
  Future<AnalyticsSnapshot> load({
    required String ownerId,
    required AnalyticsDateRange range,
    String? lifeAreaId,
  }) {
    return Future.value(
      AnalyticsMockData.snapshot(range: range, lifeAreaId: lifeAreaId),
    );
  }
}
