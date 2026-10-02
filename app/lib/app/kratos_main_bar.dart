import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/drift/app_database.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/profile_models.dart';
import '../features/progression/data/overall_progression_repository.dart';
import '../features/streaks/domain/streak_models.dart';
import '../features/streaks/presentation/streak_badge_widget.dart';
import 'kratos_skeleton.dart';
import 'kratos_theme.dart';
import 'kratos_tiers.dart';

class KratosMainBar extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final StreakInfo streakInfo;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onStreak;
  final int notificationCount;
  final bool hasUrgentNotification;

  const KratosMainBar({
    super.key,
    required this.database,
    required this.ownerId,
    required this.streakInfo,
    required this.onMenu,
    required this.onNotifications,
    required this.onStreak,
    required this.notificationCount,
    required this.hasUrgentNotification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: const Icon(Icons.menu, size: 21),
            ),
            const _KratosMark(),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<UserProfileData>(
                stream: ProfileRepository(database: database)
                    .watchProfile(ownerId),
                builder: (context, profileSnapshot) {
                  return StreamBuilder<OverallProgressionSnapshot>(
                    stream: OverallProgressionRepository(database).watch(ownerId),
                    builder: (context, progressionSnapshot) {
                      return _IdentityCluster(
                        profile: profileSnapshot.data,
                        progression: progressionSnapshot.data,
                      );
                    },
                  );
                },
              ),
            ),
            IconButton(
              tooltip: notificationCount > 0
                  ? '$notificationCount Notifications'
                  : 'Notifications',
              onPressed: onNotifications,
              icon: Badge(
                isLabelVisible: notificationCount > 0,
                backgroundColor: hasUrgentNotification
                    ? Colors.red
                    : primary,
                smallSize: 8,
                child: Icon(
                  notificationCount > 0
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  size: 20,
                ),
              ),
            ),
            InkWell(
              onTap: onStreak,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: StreakBadgeWidget(streakInfo: streakInfo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KratosMark extends StatelessWidget {
  const _KratosMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/kratos_logo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 7),
        const Text(
          'KRATOS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _IdentityCluster extends StatelessWidget {
  final UserProfileData? profile;
  final OverallProgressionSnapshot? progression;

  const _IdentityCluster({this.profile, this.progression});

  @override
  Widget build(BuildContext context) {
    if (profile == null || progression == null) {
      return const KratosShimmer(
        child: SizedBox(
          width: 150,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
        ),
      );
    }
    final global = progression!.global;
    final tier = global.currentLevel.name;
    final accent = KratosTierSystem.getGlobalColor(tier);
    final xp = NumberFormat('#,###').format(progression?.totalXp ?? 0);
    final name = profile!.displayName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final xpColor = isDark ? Colors.white60 : KratosTheme.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                global.currentLevel.romanNumeral,
                key: ValueKey(global.currentLevel.levelNumber),
                style: TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Text(
                tier.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                KratosTierSystem.getGlobalIcon(tier),
                color: accent,
                size: 15,
              ),
              const SizedBox(width: 10),
              Text(
                '$xp XP',
                style: TextStyle(
                  color: xpColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$xp XP',
                  style: TextStyle(
                    color: xpColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
