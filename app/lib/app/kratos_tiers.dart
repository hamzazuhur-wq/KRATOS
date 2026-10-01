import 'package:flutter/material.dart';

import '../data/drift/app_database.dart';
import '../features/progression/domain/global_progression.dart';
import 'kratos_theme.dart';

/// Predefined boundary for a tier in the KRATOS Experience Engine.
class TierBoundary {
  final String tierName;
  final int minXp;
  final int maxXp;

  const TierBoundary({
    required this.tierName,
    required this.minXp,
    required this.maxXp,
  });

  int get span => maxXp - minXp;

  bool contains(int xp) => xp >= minXp && xp <= maxXp;
}

/// Token representation of a KRATOS Tier.
class KratosTierToken {
  final String name;
  final Color color;
  final IconData icon;
  final int entryXp;
  final int ordinal;

  const KratosTierToken({
    required this.name,
    required this.color,
    required this.icon,
    required this.entryXp,
    required this.ordinal,
  });
}

/// Centralized KRATOS Tier & Experience Engine design system.
///
/// Ensures consistent colors, icons, boundaries, and badges across:
/// - Levels Dashboard
/// - New Level Flow
/// - Edit Level Flow
/// - Level Detail
/// - Tier Selectors
class KratosTierSystem {
  static const Map<String, Color> _tierColors = {
    'wood': Color(0xFF8D6E63),
    'bronze': Color(0xFFCD7F32),
    'silver': Color(0xFFC0C0C0),
    'gold': Color(0xFFFFD700),
    'crystal': Color(0xFF00FFFF),
    'diamond': Color(0xFFB9F2FF),
    'mythic': Color(0xFFC6F135),
  };

  static const Map<String, IconData> _tierIcons = {
    'wood': Icons.park_outlined,
    'bronze': Icons.shield_outlined,
    'silver': Icons.shield,
    'gold': Icons.workspace_premium,
    'crystal': Icons.diamond_outlined,
    'diamond': Icons.diamond,
    'mythic': Icons.military_tech,
  };

  static const List<KratosTierToken> defaultTokens = [
    KratosTierToken(
      name: 'Bronze',
      color: Color(0xFFCD7F32),
      icon: Icons.shield_outlined,
      entryXp: 1000,
      ordinal: 1,
    ),
    KratosTierToken(
      name: 'Silver',
      color: Color(0xFFC0C0C0),
      icon: Icons.shield,
      entryXp: 3000,
      ordinal: 2,
    ),
    KratosTierToken(
      name: 'Gold',
      color: Color(0xFFFFD700),
      icon: Icons.workspace_premium,
      entryXp: 7000,
      ordinal: 3,
    ),
    KratosTierToken(
      name: 'Crystal',
      color: Color(0xFF00FFFF),
      icon: Icons.diamond_outlined,
      entryXp: 15000,
      ordinal: 4,
    ),
    KratosTierToken(
      name: 'Diamond',
      color: Color(0xFFB9F2FF),
      icon: Icons.diamond,
      entryXp: 30000,
      ordinal: 5,
    ),
    KratosTierToken(
      name: 'Mythic',
      color: Color(0xFFC6F135),
      icon: Icons.military_tech,
      entryXp: 60000,
      ordinal: 6,
    ),
  ];

  /// Get the authoritative color for a tier by name.
  static Color getColor(String tierName, [String? fallbackHex]) {
    final lower = tierName.trim().toLowerCase();
    if (_tierColors.containsKey(lower)) {
      return _tierColors[lower]!;
    }
    if (fallbackHex != null && fallbackHex.isNotEmpty) {
      final normalized = fallbackHex.replaceFirst('#', '');
      final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return KratosTheme.acidLime;
  }

  /// Global progression colors come from the canonical ten-level ladder.
  /// This is intentionally separate from [getColor], which remains the
  /// established Life Area tier palette.
  static Color getGlobalColor(String levelName) {
    final definition = GlobalProgressionDefinitions.levels.firstWhere(
      (level) => level.name.toLowerCase() == levelName.toLowerCase(),
      orElse: () => GlobalProgressionDefinitions.levels.first,
    );
    final value = int.parse(definition.colorHex.substring(1), radix: 16);
    return Color(0xFF000000 | value);
  }

  static IconData getGlobalIcon(String levelName) {
    final definition = GlobalProgressionDefinitions.levels.firstWhere(
      (level) => level.name.toLowerCase() == levelName.toLowerCase(),
      orElse: () => GlobalProgressionDefinitions.levels.first,
    );
    return switch (definition.icon) {
      'shield_bronze' || 'shield_silver' || 'shield_obsidian' => Icons.shield,
      'shield_gold' => Icons.workspace_premium,
      'gem_crystal' => Icons.diamond_outlined,
      'gem_diamond' => Icons.diamond,
      'crown_mythic' || 'crown_eternal' => Icons.military_tech,
      'star_ascendant' => Icons.star,
      'flare_transcendent' => Icons.auto_awesome,
      _ => Icons.shield,
    };
  }

  /// Get the authoritative icon for a tier by name.
  static IconData getIcon(String tierName) {
    final lower = tierName.trim().toLowerCase();
    return _tierIcons[lower] ?? Icons.shield;
  }

  /// Calculate the Experience Engine boundary for the specified tier.
  ///
  /// Uses custom tiers from the database if provided, or the canonical
  /// Experience Engine defaults:
  /// - Bronze: 1,000 — 3,000 XP (or 0 — 3,000 XP if starting tier)
  /// - Silver: 3,000 — 7,000 XP
  /// - Gold: 7,000 — 15,000 XP
  /// - Crystal: 15,000 — 30,000 XP
  /// - Diamond: 30,000 — 60,000 XP
  /// - Mythic: 60,000 — 100,000 XP
  static TierBoundary getBoundary(
    String tierName, [
    List<TierDefinition>? customTiers,
  ]) {
    final cleanName = tierName.trim();
    final lower = cleanName.toLowerCase();

    if (customTiers != null && customTiers.isNotEmpty) {
      final sorted = List<TierDefinition>.from(customTiers)
        ..sort((a, b) => a.entryXp.compareTo(b.entryXp));

      final index = sorted.indexWhere((t) => t.name.toLowerCase() == lower);
      if (index != -1) {
        final current = sorted[index];
        final isFirst = index == 0;
        final isLast = index == sorted.length - 1;

        final minXp =
            isFirst && !sorted.any((t) => t.name.toLowerCase() == 'wood')
            ? 0
            : current.entryXp;
        final maxXp = isLast
            ? (current.entryXp + 40000)
            : sorted[index + 1].entryXp;

        return TierBoundary(tierName: current.name, minXp: minXp, maxXp: maxXp);
      }
    }

    // Default Experience Engine boundaries
    switch (lower) {
      case 'wood':
        return const TierBoundary(tierName: 'Wood', minXp: 0, maxXp: 1000);
      case 'bronze':
        return const TierBoundary(tierName: 'Bronze', minXp: 1000, maxXp: 3000);
      case 'silver':
        return const TierBoundary(tierName: 'Silver', minXp: 3000, maxXp: 7000);
      case 'gold':
        return const TierBoundary(tierName: 'Gold', minXp: 7000, maxXp: 15000);
      case 'crystal':
        return const TierBoundary(
          tierName: 'Crystal',
          minXp: 15000,
          maxXp: 30000,
        );
      case 'diamond':
        return const TierBoundary(
          tierName: 'Diamond',
          minXp: 30000,
          maxXp: 60000,
        );
      case 'mythic':
        return const TierBoundary(
          tierName: 'Mythic',
          minXp: 60000,
          maxXp: 100000,
        );
      default:
        return const TierBoundary(tierName: 'Custom', minXp: 0, maxXp: 5000);
    }
  }

  /// Build a leading icon circle for dropdowns and triggers.
  static Widget buildTierLeadingIcon(String tierName, {double size = 16}) {
    final color = getColor(tierName);
    final icon = getIcon(tierName);

    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Center(
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  /// Build a stylized tier pill badge.
  static Widget buildTierPill(
    String tierName, {
    bool showIcon = true,
    Color? customColor,
    double fontSize = 11,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 3,
    ),
  }) {
    final color = customColor ?? getColor(tierName);
    final icon = getIcon(tierName);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, color: color, size: fontSize + 2),
            const SizedBox(width: 5),
          ],
          Text(
            tierName.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
