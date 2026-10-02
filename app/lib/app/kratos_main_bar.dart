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
  final String? currentSection;

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
    this.currentSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final iconColor = isDark ? Colors.white70 : KratosTheme.lightTextPrimary;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF2121513),
                    Color(0xEB0A0D0B),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF8FFFFFF),
                    Color(0xF2F7F8FA),
                  ],
                ),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0x1F0F172A),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0x0A0F172A),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top specular hairline
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isDark ? Colors.white : accent).withValues(
                        alpha: isDark ? 0.16 : 0.20,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: onMenu,
                    icon: Icon(Icons.menu, color: iconColor, size: 21),
                  ),
                  _KratosMark(sectionTitle: currentSection),
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
                          ? const Color(0xFFFF3B30)
                          : accent,
                      smallSize: 8,
                      child: Icon(
                        notificationCount > 0
                            ? Icons.notifications_active
                            : Icons.notifications_outlined,
                        color: notificationCount > 0
                            ? (hasUrgentNotification
                                ? const Color(0xFFFF3B30)
                                : accent)
                            : (isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
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
          ],
        ),
      ),
    );
  }
}

class _KratosMark extends StatelessWidget {
  final String? sectionTitle;
  const _KratosMark({this.sectionTitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final screenWidth = MediaQuery.of(context).size.width;
    final showSection = sectionTitle != null && screenWidth >= 640;

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
        Text(
          'KRATOS',
          style: TextStyle(
            color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            fontSize: 13,
          ),
        ),
        if (showSection) ...[
          const SizedBox(width: 8),
          Text(
            '/',
            style: TextStyle(
              color: (isDark ? Colors.white : KratosTheme.lightTextSecondary).withValues(alpha: 0.25),
              fontWeight: FontWeight.w300,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            sectionTitle!,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ],
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
