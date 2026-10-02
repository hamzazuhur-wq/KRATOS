// ignore_for_file: public_member_api_docs
// Wave 1: Liquid Glass Goal Card with Calm Pulsing Status Aesthetics.
// Adheres strictly to kratos-ui-liquid-glass design specifications.

import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';

class GoalCard extends StatefulWidget {
  final Goal goal;
  final String? lifeAreaName;
  final String? categoryName;
  final int childGoalsCount;
  final int linkedTasksCount;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    this.lifeAreaName,
    this.categoryName,
    this.childGoalsCount = 0,
    this.linkedTasksCount = 0,
    required this.onTap,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.goal.status == 'active' ||
        widget.goal.status == 'paused' ||
        widget.goal.status == 'stopped') {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant GoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.status != oldWidget.goal.status) {
      if (widget.goal.status == 'completed' || widget.goal.status == 'abandoned') {
        _pulseController.stop();
      } else if (!_pulseController.isAnimating) {
        _pulseController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.goal.status.toLowerCase()) {
      case 'active':
        return const Color(0xFFC6F135); // Acid Lime
      case 'paused':
        return const Color(0xFFFF9500); // Warm Amber
      case 'stopped':
        return const Color(0xFFFF3B30); // Volcanic Red
      case 'completed':
        return const Color(0xFF30D158); // Calm Green
      default:
        return Colors.white38;
    }
  }

  String _getStatusLabel() {
    switch (widget.goal.status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'paused':
        return 'PAUSED';
      case 'stopped':
        return 'STOPPED';
      case 'completed':
        return 'COMPLETED';
      default:
        return widget.goal.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();
    final isStatic = widget.goal.status == 'completed' || widget.goal.status == 'abandoned';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = isStatic ? 0.2 : _pulseAnimation.value * 0.45;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.interactive,
            interactive: true,
            accentColor: statusColor.withValues(alpha: glowOpacity < 0.22 ? 0.22 : glowOpacity),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  splashColor: statusColor.withValues(alpha: 0.1),
                  highlightColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Metadata Tags
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.lifeAreaName != null) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : Colors.black12,
                                    ),
                                  ),
                                  child: Text(
                                    widget.lifeAreaName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.categoryName != null) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC6F135).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    widget.categoryName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (widget.goal.xpTarget != null && widget.goal.xpTarget! > 0)
                              Row(
                                children: [
                                  const Icon(Icons.bolt,
                                      color: Color(0xFFC6F135), size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${widget.goal.xpTarget} XP',
                                    style: const TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          widget.goal.title,
                          style: TextStyle(
                            color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (widget.goal.description != null &&
                            widget.goal.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.goal.description!,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Progress bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widget.goal.progress.clamp(0.0, 1.0),
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(widget.goal.progress * 100).toInt()}%',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bottom Meta: Sub-goals count, Tasks count, Last updated
                        Row(
                          children: [
                            if (widget.childGoalsCount > 0) ...[
                              Icon(
                                Icons.account_tree_outlined,
                                size: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.childGoalsCount} sub-goals',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : KratosTheme.lightTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (widget.linkedTasksCount > 0) ...[
                              Icon(
                                Icons.check_circle_outline,
                                size: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.linkedTasksCount} tasks',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : KratosTheme.lightTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            const Spacer(),
                            Text(
                              _formatDate(widget.goal.updatedAt),
                              style: TextStyle(
                                color: isDark ? Colors.white24 : KratosTheme.lightTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ),
            ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
