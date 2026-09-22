// Wave 7: StreakService.
// Connects domain layer with StreaksDao and computes StreakInfo.

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../data/streaks_dao.dart';
import 'streak_models.dart';

class StreakService {
  final StreaksDao _dao;

  StreakService(AppDatabase db) : _dao = StreaksDao(db);

  /// Fetch the current streak and freeze inventory for a LifeArea.
  Future<StreakInfo> getStreakForLifeArea({
    required Id userId,
    required Id lifeAreaId,
  }) async {
    final streak = await _dao.getStreak(userId.value, lifeAreaId.value);
    final freeze =
        await _dao.getFreezeInventory(userId.value, lifeAreaId.value);

    return StreakInfo.create(
      userId: userId,
      lifeAreaId: lifeAreaId,
      currentStreak: streak?.currentStreak ?? 0,
      longestStreak: streak?.longestStreak ?? 0,
      freezeTokensAvailable: freeze?.tokensAvailable ?? 2,
      lastActiveDate: streak?.lastActiveDate,
    );
  }

  /// Process streak upon logging activity in a LifeArea.
  Future<StreakActivityResult> logActivity({
    required Id userId,
    required Id lifeAreaId,
    required DateTime activityDate,
    required String versionHlc,
  }) {
    return _dao.processActivity(
      userId: userId.value,
      lifeAreaId: lifeAreaId.value,
      activityDate: activityDate,
      versionHlc: versionHlc,
    );
  }
}
