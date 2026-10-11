import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../../../data/drift/app_database.dart';
import '../../../../sessions/domain/global_active_session_controller.dart';
import '../../../../sessions/presentation/session_timer_screen.dart';

/// Live Active Session banner mounted above or inside Focus Time dashboard.
///
/// If a session is active in [GlobalActiveSessionController], displays:
/// - Real-time elapsed time calculated strictly from persisted timestamps
/// - Active activity/task title
/// - Pause / Resume and Stop / Complete controls
///
/// If idle, provides a sleek quick-start action.
class FocusTimeActiveSessionCard extends StatefulWidget {
  final VoidCallback? onStartFocusTap;
  final AppDatabase? database;
  final String? ownerId;

  const FocusTimeActiveSessionCard({
    super.key,
    this.onStartFocusTap,
    this.database,
    this.ownerId,
  });

  @override
  State<FocusTimeActiveSessionCard> createState() =>
      _FocusTimeActiveSessionCardState();
}

class _FocusTimeActiveSessionCardState
    extends State<FocusTimeActiveSessionCard> {
  final _controller = GlobalActiveSessionController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;

    return StreamBuilder<ActiveSessionState?>(
      stream: _controller.stream,
      initialData: _controller.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;

        if (state == null) {
          // Idle state — compact invitation strip
          return KratosGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x1FFFFFFF)
                        : const Color(0x0F0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: limeAccent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ready to track focus?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        'Start a session to earn XP and build your streak.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (widget.onStartFocusTap != null) {
                      widget.onStartFocusTap!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SessionTimerScreen(
                            contextLabel: 'Deep Focus Session',
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x2EEFFF08)
                          : const Color(0x2284CC16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x4DEEFF08)
                            : const Color(0x5584CC16),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start Focus',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? limeAccent
                                : const Color(0xFF4D7C0F),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: isDark
                              ? limeAccent
                              : const Color(0xFF4D7C0F),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Active / Paused session
        final isPaused = state.isPaused;
        final statusLabel = isPaused ? 'PAUSED' : 'ACTIVE FOCUS SESSION';
        final statusColor = isPaused ? Colors.amberAccent : limeAccent;

        return KratosGlassCard(
          variant: isPaused ? KratosSurfaceVariant.normal : KratosSurfaceVariant.active,
          accentColor: isPaused ? Colors.amberAccent : limeAccent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Pulsing status dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Activity Title + Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Live elapsed timer readout
              Text(
                state.formattedElapsed,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(width: 16),
              // Pause / Resume button
              IconButton(
                onPressed: () {
                  if (isPaused) {
                    _controller.resumeSession();
                  } else {
                    _controller.pauseSession();
                  }
                },
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: primaryTextColor,
                ),
                tooltip: isPaused ? 'Resume' : 'Pause',
              ),
              // Complete / Stop button
              IconButton(
                onPressed: () {
                  _controller.completeSession();
                },
                icon: const Icon(
                  Icons.stop_rounded,
                  color: Colors.redAccent,
                ),
                tooltip: 'Complete session',
              ),
            ],
          ),
        );
      },
    );
  }
}
