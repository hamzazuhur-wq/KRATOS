// ignore_for_file: public_member_api_docs
// Wave 04: Liquid Glass Goal Card with Architectural Precision and Manus Tokens.
// Uses Space Grotesk, IBM Plex Mono, Inter, and E1/E2/E3 surface discipline.

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

class _GoalCardState extends State<GoalCard> {
  Color _getStatusColor() {
    switch (widget.goal.status.toLowerCase()) {
      case 'active':
        return KratosTheme.electricLime;
      case 'paused':
        return const Color(0xFFFF9500);
      case 'stopped':
        return const Color(0xFFFF3B30);
      case 'completed':
        return const Color(0xFF30D158);
      default:
        return const Color(0xFF686D65);
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
    final isCompleted = widget.goal.status.toLowerCase() == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KratosGlassCard(
        variant: isCompleted ? KratosSurfaceVariant.normal : KratosSurfaceVariant.interactive,
        interactive: true,
        accentColor: statusColor.withValues(alpha: isDark ? 0.40 : 0.45),
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: statusColor.withValues(alpha: 0.12),
            highlightColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Status & Hierarchy Eyebrows & XP chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: isDark ? 0.12 : 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: isDark ? 0.45 : 0.40),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(),
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: statusColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                            // Hierarchy depth badge if sub-goal
                            if (widget.goal.depth > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0C10130F),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : const Color(0x1410130F),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 10,
                                      color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'D${widget.goal.depth}',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Life Area
                            if (widget.lifeAreaName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A10130F),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0x1010130F),
                                  ),
                                ),
                                child: Text(
                                  widget.lifeAreaName!.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),

                            // Category
                            if (widget.categoryName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? KratosTheme.electricLime.withValues(alpha: 0.08)
                                      : const Color(0x14A8B800),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? KratosTheme.electricLime.withValues(alpha: 0.25)
                                        : const Color(0x28A8B800),
                                  ),
                                ),
                                child: Text(
                                  widget.categoryName!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: isDark ? KratosTheme.electricLime : const Color(0xFF718000),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // XP Target
                      if (widget.goal.xpTarget != null && widget.goal.xpTarget! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? KratosTheme.electricLime.withValues(alpha: 0.10)
                                : const Color(0x14A8B800),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? KratosTheme.electricLime.withValues(alpha: 0.22)
                                  : const Color(0x28A8B800),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                color: isDark ? KratosTheme.electricLime : const Color(0xFF718000),
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '+${widget.goal.xpTarget} XP',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: isDark ? KratosTheme.electricLime : const Color(0xFF718000),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title (Space Grotesk)
                  Text(
                    widget.goal.title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                        fontFamily: 'Inter',
                        color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Progress Bar (Manus standard progress)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 6,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: widget.goal.progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? statusColor
                                        : (isCompleted
                                            ? const Color(0xFF30D158)
                                            : KratosTheme.lightAcidLime),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(widget.goal.progress * 100).round()}%',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: isDark
                              ? statusColor
                              : (isCompleted
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFF718000)),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Footer: Hierarchy sub-goals count, tasks count, date metadata
                  Row(
                    children: [
                      if (widget.childGoalsCount > 0) ...[
                        Icon(
                          Icons.account_tree_outlined,
                          size: 13,
                          color: isDark ? const Color(0xFF686D65) : Colors.black38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.childGoalsCount} sub-goals',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (widget.linkedTasksCount > 0) ...[
                        Icon(
                          Icons.check_circle_outline,
                          size: 13,
                          color: isDark ? const Color(0xFF686D65) : Colors.black38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.linkedTasksCount} tasks',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      const Spacer(),
                      Text(
                        _formatDate(widget.goal.updatedAt),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: isDark ? const Color(0xFF686D65) : KratosTheme.lightTextMuted,
                          fontSize: 9.5,
                          letterSpacing: 0.5,
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
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    if (diff.inDays < 7) return '${diff.inDays}D AGO';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
