import 'package:flutter/material.dart';

/// Compact Kratos status indicator shared by every active timer surface.
class TimerStatusBadge extends StatefulWidget {
  final bool isPaused;

  const TimerStatusBadge({super.key, this.isPaused = false});

  @override
  State<TimerStatusBadge> createState() => _TimerStatusBadgeState();
}

class _TimerStatusBadgeState extends State<TimerStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPaused ? Colors.amber : const Color(0xFFC6F135);
    final label = widget.isPaused ? 'PAUSED' : 'TIMING ON';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12 + (_pulse.value * 0.08)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12 * _pulse.value),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
