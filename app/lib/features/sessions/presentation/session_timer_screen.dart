// Wave 9: Session timer screen — Liquid Glass / Acid Lime.
// Active focus timer with start/pause/end flow.
// Session XP is awarded via XpLedgerWriter after the timer ends.

import 'dart:async';

import 'package:flutter/material.dart';

/// Stateful focus timer widget for a single KRATOS session.
///
/// Integrates with [SessionsDao] and [XpLedgerWriter] (wired via Riverpod
/// in the full implementation). This screen manages the local timer state.
class SessionTimerScreen extends StatefulWidget {
  /// Optional task or activity name shown in the header.
  final String? contextLabel;

  /// Optional XP estimate shown while running.
  final int? estimatedXp;

  const SessionTimerScreen({
    super.key,
    this.contextLabel,
    this.estimatedXp,
  });

  @override
  State<SessionTimerScreen> createState() => _SessionTimerScreenState();
}

class _SessionTimerScreenState extends State<SessionTimerScreen>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  bool _isCompleted = false;

  // Liquid Glass pulse animation controller
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _endSession() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
    });
    // TODO(Wave 9 impl): call SessionsDao.endSession() then XpLedgerWriter.record()
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SessionCompletedDialog(
        elapsed: _elapsed,
        estimatedXp: widget.estimatedXp,
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.contextLabel?.toUpperCase() ?? 'FOCUS SESSION',
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated timer ring
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) {
                return Transform.scale(
                  scale: _isRunning ? _pulseAnim.value : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning
                      ? const Color(0xFFC6F135).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: _isRunning
                        ? const Color(0xFFC6F135)
                        : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: _isRunning
                      ? [
                          BoxShadow(
                            color: const Color(0xFFC6F135).withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_elapsed),
                      style: TextStyle(
                        color: _isRunning
                            ? const Color(0xFFC6F135)
                            : Colors.white70,
                        fontSize: 48,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 2,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (_isRunning)
                      const Text(
                        'RUNNING',
                        style: TextStyle(
                          color: Color(0xFFC6F135),
                          fontSize: 10,
                          letterSpacing: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // XP estimate chip
            if (widget.estimatedXp != null && _isRunning)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '~${widget.estimatedXp} XP on completion',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            // Controls
            if (!_isCompleted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isRunning)
                    _TimerButton(
                      label: _elapsed == Duration.zero ? 'START' : 'RESUME',
                      icon: Icons.play_arrow,
                      color: const Color(0xFFC6F135),
                      onTap: _startTimer,
                    )
                  else
                    _TimerButton(
                      label: 'PAUSE',
                      icon: Icons.pause,
                      color: Colors.white60,
                      onTap: _pauseTimer,
                    ),
                  const SizedBox(width: 20),
                  if (_elapsed.inSeconds >= 30)
                    _TimerButton(
                      label: 'END',
                      icon: Icons.stop,
                      color: const Color(0xFFFF3B30),
                      onTap: _endSession,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TimerButton — Liquid Glass action button
// ---------------------------------------------------------------------------

class _TimerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TimerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SessionCompletedDialog — XP award confirmation
// ---------------------------------------------------------------------------

class _SessionCompletedDialog extends StatelessWidget {
  final Duration elapsed;
  final int? estimatedXp;
  final VoidCallback onConfirm;

  const _SessionCompletedDialog({
    required this.elapsed,
    required this.estimatedXp,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: Color(0xFFC6F135), size: 52),
            const SizedBox(height: 16),
            const Text(
              'SESSION COMPLETE',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${minutes}m focused',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (estimatedXp != null) ...[
              const SizedBox(height: 8),
              Text(
                '+$estimatedXp XP awarded',
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onConfirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    color: Color(0xFF0D0D0D),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
