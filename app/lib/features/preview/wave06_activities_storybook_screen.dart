import 'package:flutter/material.dart';
import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../../app/kratos_visuals.dart';
import '../activities/domain/activity_models.dart';

/// Wave 06 Storybook / Widget Previews Showcase.
/// Renders every existing Activities, Focus, and Sessions variant across Dark and Light mode:
/// 1. Activity Cards (Normal, Elevated, Active with live timer, and Paused)
/// 2. Activity Metrics and Progress Sheen
/// 3. Focus Timer Surface (Active pulse ring, tabular numeric readout, Start/Pause/Complete controls)
/// 4. Time Capture & Elapsed Controls
/// 5. Recent Completed Session Logs & XP Award Badges
/// 6. Empty State (Manus-compliant zero-activity card)
class Wave06StorybookScreen extends StatelessWidget {
  const Wave06StorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {

    // Mock Item 1: Active Routine (Gym & Resistance)
    final activeItem = ActivityDashboardItem(
      id: 'act-1',
      name: 'High Intensity Resistance Training',
      description: 'Heavy compound movements and progressive overload.',
      lifeAreaId: 'la-health',
      lifeAreaName: 'HEALTH & VITALITY',
      categoryId: 'cat-fitness',
      categoryName: 'FITNESS',
      targetDurationMinutes: 45,
      difficulty: 8,
      periodSessionCount: 14,
      periodTrackedDurationMs: 14 * 45 * 60 * 1000,
      periodXpEarned: 1120,
    );

    // Mock Item 2: Focus Routine (Deep Work / Architecture)
    final codingItem = ActivityDashboardItem(
      id: 'act-2',
      name: 'Systems Architecture & Rust Kernels',
      description: 'Low-level async runtime and deterministic execution engine.',
      lifeAreaId: 'la-craft',
      lifeAreaName: 'CRAFT & CODE',
      categoryId: 'cat-arch',
      categoryName: 'ARCHITECTURE',
      targetDurationMinutes: 90,
      difficulty: 9,
      periodSessionCount: 22,
      periodTrackedDurationMs: 22 * 90 * 60 * 1000,
      periodXpEarned: 2450,
    );

    // Mock Item 3: Paused / Standby Activity
    final readingItem = ActivityDashboardItem(
      id: 'act-3',
      name: 'Philosophy & Decision Mental Models',
      description: 'First principles mental models and cognitive bias reflection.',
      lifeAreaId: 'la-mind',
      lifeAreaName: 'MIND & COGNITION',
      categoryId: 'cat-study',
      categoryName: 'STUDY',
      targetDurationMinutes: 30,
      difficulty: 5,
      periodSessionCount: 8,
      periodTrackedDurationMs: 8 * 30 * 60 * 1000,
      periodXpEarned: 400,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary;
    final limeColor = isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: limeColor.withValues(alpha: isDark ? 0.12 : 0.10),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: limeColor.withValues(alpha: isDark ? 0.35 : 0.40),
                ),
              ),
              child: Text(
                'WAVE 06',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: limeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ACTIVITIES · FOCUS · SESSIONS SHOWCASE',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: limeColor,
              size: 20,
            ),
            onPressed: () => KratosThemeController.instance.toggle(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Activity Overview & Normal Surface
              _buildSectionTitle('1. ACTIVITY CARD — STANDARD (E1 NORMAL GLASS)'),
              const SizedBox(height: 10),
              _buildMockActivityCard(
                context: context,
                item: readingItem,
                isActive: false,
                isPaused: false,
                variant: KratosSurfaceVariant.normal,
              ),
              const SizedBox(height: 24),

              // 2. Elevated Activity Card
              _buildSectionTitle('2. ACTIVITY CARD — ELEVATED (E2 HIGH PRIORITY)'),
              const SizedBox(height: 10),
              _buildMockActivityCard(
                context: context,
                item: codingItem,
                isActive: false,
                isPaused: false,
                variant: KratosSurfaceVariant.elevated,
              ),
              const SizedBox(height: 24),

              // 3. Active Session Surface (E3 Active State)
              _buildSectionTitle('3. ACTIVE FOCUS SESSION CARD (E3 ACTIVE STROKE & LIVE TIMER)'),
              const SizedBox(height: 10),
              _buildMockActivityCard(
                context: context,
                item: activeItem,
                isActive: true,
                isPaused: false,
                elapsedText: '00:34:18',
                variant: KratosSurfaceVariant.active,
              ),
              const SizedBox(height: 24),

              // 4. Paused State
              _buildSectionTitle('4. PAUSED FOCUS SESSION CARD (AMBER WARNING INDICATOR)'),
              const SizedBox(height: 10),
              _buildMockActivityCard(
                context: context,
                item: activeItem,
                isActive: true,
                isPaused: true,
                elapsedText: '00:19:42',
                variant: KratosSurfaceVariant.active,
              ),
              const SizedBox(height: 24),

              // 5. Focus Timer Command Surface
              _buildSectionTitle('5. FOCUS TIMER COMMAND INTERFACE (CALM OS READOUT)'),
              const SizedBox(height: 10),
              KratosGlassCard(
                variant: KratosSurfaceVariant.elevated,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'ACTIVE COMMAND: DEEP FOCUS',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: limeColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: limeColor.withValues(alpha: isDark ? 0.06 : 0.08),
                        border: Border.all(
                          color: limeColor.withValues(alpha: isDark ? 0.8 : 0.9),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: limeColor.withValues(alpha: isDark ? 0.15 : 0.12),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '42:15',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 44,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            'TARGET 90M',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimerActionButton(
                          label: 'PAUSE',
                          icon: Icons.pause,
                          color: isDark ? Colors.amber : const Color(0xFFB45309),
                          onTap: () {},
                        ),
                        const SizedBox(width: 14),
                        _buildTimerActionButton(
                          label: 'COMPLETE (+90 XP)',
                          icon: Icons.check_circle_outline,
                          color: limeColor,
                          isPrimary: true,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6. Recent Completed Session Logs & XP Allocation
              _buildSectionTitle('6. TIME CAPTURE & RECENT SESSION LOG ENTRIES'),
              const SizedBox(height: 10),
              KratosGlassCard(
                variant: KratosSurfaceVariant.normal,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT SESSIONS AUDIT',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: limeColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'CYCLE: TODAY',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSessionLogRow(
                      title: 'Morning Resistance Training',
                      duration: '45m 12s',
                      xp: '+90 XP',
                      area: 'HEALTH',
                      time: '08:30 AM',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeColor: limeColor,
                    ),
                    Divider(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x1F0F172A),
                      height: 20,
                    ),
                    _buildSessionLogRow(
                      title: 'Drift Web WASM Schema Architecture',
                      duration: '90m 00s',
                      xp: '+180 XP',
                      area: 'CRAFT',
                      time: '11:15 AM',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeColor: limeColor,
                    ),
                    Divider(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x1F0F172A),
                      height: 20,
                    ),
                    _buildSessionLogRow(
                      title: 'Weekly Systems Review',
                      duration: '30m 00s',
                      xp: '+60 XP',
                      area: 'PERSONAL',
                      time: '04:45 PM',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeColor: limeColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 7. Empty State
              _buildSectionTitle('7. ZERO ACTIVITIES / EMPTY STATE'),
              const SizedBox(height: 10),
              Center(
                child: KratosGlassCard(
                  variant: KratosSurfaceVariant.normal,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: limeColor.withValues(alpha: isDark ? 0.08 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: limeColor.withValues(alpha: isDark ? 0.25 : 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.repeat_outlined,
                            color: limeColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ZERO RECURRENT SESSIONS',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No Activities Registered',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Define recurring habits, training blocks, and deep craft practices to log time and claim XP progression.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final limeColor = isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;
        final titleColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

        return Row(
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: limeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMockActivityCard({
    required BuildContext context,
    required ActivityDashboardItem item,
    required bool isActive,
    required bool isPaused,
    String elapsedText = '00:00:00',
    required KratosSurfaceVariant variant,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary;
    final limeColor = isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;

    return KratosGlassCard(
      variant: variant,
      interactive: true,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: limeColor.withValues(alpha: isDark ? 0.12 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: limeColor.withValues(alpha: isDark ? 0.25 : 0.35),
                  ),
                ),
                child: Icon(
                  Icons.local_activity,
                  color: limeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.lifeAreaName != null)
                          _badge(item.lifeAreaName!, limeColor),
                        if (item.categoryName != null)
                          _badge(item.categoryName!, const Color(0xFF00BCD4)),
                        if (item.targetDurationMinutes != null)
                          _badge(
                            'TARGET ${item.formattedTargetDuration}',
                            const Color(0xFFE5C07B),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action buttons / Live state
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isPaused ? Colors.amber : limeColor)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPaused ? Colors.amber : limeColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPaused ? Colors.amber : limeColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        elapsedText,
                        style: TextStyle(
                          color: isPaused ? Colors.amber : limeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'IBM Plex Mono',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: limeColor,
                        size: 22,
                      ),
                      onPressed: () {},
                      tooltip: 'Quick Log Session',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_fill,
                        color: limeColor,
                        size: 26,
                      ),
                      onPressed: () {},
                      tooltip: 'Start Focus Timer',
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : const Color(0x0A0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.periodSessionCount} Sessions • ${item.formattedPeriodDuration}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '+${item.periodXpEarned} XP',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: limeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildTimerActionButton({
    required String label,
    required IconData icon,
    required Color color,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isPrimary
                  ? color
                  : color.withValues(alpha: isDark ? 0.12 : 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary ? color : color.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isPrimary ? Colors.black : color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: isPrimary ? Colors.black : color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionLogRow({
    required String title,
    required String duration,
    required String xp,
    required String area,
    required String time,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color limeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: limeColor.withValues(alpha: isDark ? 0.12 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 14, color: limeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: primaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$area • $time',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: secondaryTextColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          duration,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: secondaryTextColor,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: limeColor.withValues(alpha: isDark ? 0.15 : 0.20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            xp,
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              color: limeColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
