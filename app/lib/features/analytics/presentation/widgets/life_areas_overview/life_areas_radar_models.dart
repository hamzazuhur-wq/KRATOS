import 'package:flutter/material.dart';

import '../../../../progression/domain/progression_calculator.dart';
import '../../../domain/analytics_models.dart';

/// Normalized domain representation for a single Life Area axis in the Radar visualization.
@immutable
class RadarLifeAreaEntry {
  final String id;
  final String name;
  final double normalizedProgress; // Clamped 0.0 .. 1.0
  final int displayPct; // 0 .. 100
  final int xp; // Lifetime/total XP in this domain
  final int xpInLevel;
  final int xpToNext;
  final int level;
  final String tier;
  final double trendPct;
  final IconData icon;
  final Color color;
  final int activityCount;
  final int completionCount;

  const RadarLifeAreaEntry({
    required this.id,
    required this.name,
    required this.normalizedProgress,
    required this.displayPct,
    required this.xp,
    required this.xpInLevel,
    required this.xpToNext,
    required this.level,
    required this.tier,
    required this.trendPct,
    required this.icon,
    required this.color,
    required this.activityCount,
    required this.completionCount,
  });

  /// Factory creating an entry from an [AnalyticsLifeAreaMetric].
  factory RadarLifeAreaEntry.fromMetric(AnalyticsLifeAreaMetric metric) {
    final clampedProgress = metric.progress.isNaN || metric.progress.isInfinite
        ? 0.0
        : metric.progress.clamp(0.0, 1.0);

    final info = ProgressionCalculator.calculate(totalXp: metric.xp);
    final icon = resolveLifeAreaIcon(metric.name, metric.id);
    final parsedColor = _parseColor(metric.color);

    return RadarLifeAreaEntry(
      id: metric.id,
      name: metric.name,
      normalizedProgress: clampedProgress,
      displayPct: (clampedProgress * 100).round().clamp(0, 100),
      xp: metric.xp,
      xpInLevel: info.xpInLevel,
      xpToNext: info.xpToNext > 0 ? info.xpToNext : 1000,
      level: metric.level > 0 ? metric.level : info.level,
      tier: metric.tier.isNotEmpty ? metric.tier : info.tier,
      trendPct: metric.trendPct,
      icon: icon,
      color: parsedColor,
      activityCount: metric.activityCount,
      completionCount: metric.completionCount,
    );
  }

  static Color _parseColor(String colorStr) {
    try {
      final hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFEEFF08); // Kratos Acid Lime fallback
  }

  RadarLifeAreaEntry copyWithProgress(double newProgress) {
    final clamped = newProgress.clamp(0.0, 1.0);
    return RadarLifeAreaEntry(
      id: id,
      name: name,
      normalizedProgress: clamped,
      displayPct: (clamped * 100).round().clamp(0, 100),
      xp: xp,
      xpInLevel: xpInLevel,
      xpToNext: xpToNext,
      level: level,
      tier: tier,
      trendPct: trendPct,
      icon: icon,
      color: color,
      activityCount: activityCount,
      completionCount: completionCount,
    );
  }
}

/// Authoritative icon resolution for KRATOS Life Areas.
IconData resolveLifeAreaIcon(String name, [String? id]) {
  final lower = name.toLowerCase();
  final idLower = (id ?? '').toLowerCase();

  if (lower.contains('health') ||
      lower.contains('physical') ||
      lower.contains('sport') ||
      lower.contains('fitness') ||
      idLower.contains('health')) {
    return Icons.directions_run_rounded;
  }
  if (lower.contains('wealth') ||
      lower.contains('career') ||
      lower.contains('finance') ||
      lower.contains('money') ||
      idLower.contains('career') ||
      idLower.contains('wealth')) {
    return Icons.savings_outlined;
  }
  if (lower.contains('relation') ||
      lower.contains('social') ||
      lower.contains('family') ||
      lower.contains('love') ||
      idLower.contains('relation')) {
    return Icons.favorite_border_rounded;
  }
  if (lower.contains('knowledge') ||
      lower.contains('mind') ||
      lower.contains('learn') ||
      lower.contains('education') ||
      lower.contains('study') ||
      idLower.contains('mind') ||
      idLower.contains('knowledge')) {
    return Icons.school_outlined;
  }
  if (lower.contains('creativ') ||
      lower.contains('art') ||
      lower.contains('idea') ||
      lower.contains('design') ||
      lower.contains('innovat') ||
      idLower.contains('creativ')) {
    return Icons.lightbulb_outline_rounded;
  }
  if (lower.contains('peace') ||
      lower.contains('spirit') ||
      lower.contains('zen') ||
      lower.contains('inner') ||
      lower.contains('mindful') ||
      idLower.contains('peace')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.track_changes_rounded;
}
