import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/xp_progress_models.dart';

/// Bottom-Right XP Sources Breakdown with clean horizontal progress bars (Section 17).
///
/// Features:
/// - Real source breakdown from AnalyticsSnapshot.xpBySource
/// - Clean horizontal bars (thin, rounded, monochrome track with Acid Lime fill)
/// - Exact XP values and calculated percentages
/// - Safe fallback for unknown sources.
class XpProgressSources extends StatelessWidget {
  final List<XpSourceMetric> sources;
  final bool isDark;
  final Color? accentColor;

  const XpProgressSources({
    super.key,
    required this.sources,
    required this.isDark,
    this.accentColor,
  });

  String _formatNumber(int n) {
    final s = n.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return '${n < 0 ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ────────────────────────────────────────────────────
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                'XP Sources',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '(This Period)',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── List of Source Rows ───────────────────────────────────────────
          if (sources.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No XP recorded for this period.',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ),
            )
          else
            ...sources.map((s) => _buildSourceRow(s, primary, secondary, lime)),
        ],
      ),
    );
  }

  Widget _buildSourceRow(
    XpSourceMetric source,
    Color primary,
    Color secondary,
    Color lime,
  ) {
    final trackColor = isDark ? const Color(0xFF202326) : const Color(0xFFD8DADB);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Source Icon
          Icon(
            source.icon,
            size: 15,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),

          // Source Name
          SizedBox(
            width: 78,
            child: Text(
              source.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Exact XP
          SizedBox(
            width: 70,
            child: Text(
              '${_formatNumber(source.xp)} XP',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 14),

          // Horizontal Progress Bar
          Expanded(
            child: Container(
              height: 6.5,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(3.5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (source.percent / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: lime,
                    borderRadius: BorderRadius.circular(3.5),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: lime.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Percentage Label
          SizedBox(
            width: 38,
            child: Text(
              '${source.percent.round()}%',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
