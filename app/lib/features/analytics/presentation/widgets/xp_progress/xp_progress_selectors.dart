import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../domain/analytics_models.dart';

/// Compact Black Liquid Glass Dropdown Popover Selector for Life Areas.
///
/// Adheres strictly to Section 6:
/// - Compact pill trigger: [ ◇ Professional ▾ ]
/// - Translucent glass popover
/// - Supports "All Life Areas" and all real Life Areas
/// - Scrollable if many Life Areas are present
/// - Minimal Apple-inspired Liquid Glass aesthetic
/// - Isolated card-level state (does not mutate global page filters).
class XpLifeAreaSelector extends StatelessWidget {
  final String? selectedId;
  final String selectedName;
  final List<({String id, String name})> lifeAreas;
  final ValueChanged<String?> onSelected;
  final bool isDark;

  const XpLifeAreaSelector({
    super.key,
    required this.selectedId,
    required this.selectedName,
    required this.lifeAreas,
    required this.onSelected,
    required this.isDark,
  });

  void _showPopover(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height + 4,
      offset.dx + size.width,
      offset.dy + size.height + 4,
    );

    final selected = await showMenu<String?>(
      context: context,
      position: position,
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      items: [
        PopupMenuItem<String?>(
          value: null,
          height: 40,
          child: _PopoverItemContent(
            label: 'All Life Areas',
            icon: Icons.track_changes_outlined,
            isSelected: selectedId == null,
            isDark: isDark,
          ),
        ),
        for (final area in lifeAreas)
          PopupMenuItem<String?>(
            value: area.id,
            height: 40,
            child: _PopoverItemContent(
              label: area.name,
              icon: Icons.adjust_rounded,
              isSelected: selectedId == area.id,
              isDark: isDark,
            ),
          ),
      ],
    );

    if (selected != selectedId) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lime = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final textPrimary = isDark ? Colors.white : KratosTheme.lightTextPrimary;

    return InkWell(
      onTap: () => _showPopover(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x1F0F172A),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.track_changes_outlined,
              size: 14.5,
              color: lime,
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                selectedName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Dropdown Popover Selector for Time Ranges (Section 8).
class XpTimeRangeSelector extends StatelessWidget {
  final AnalyticsPeriod selectedPeriod;
  final ValueChanged<AnalyticsPeriod> onSelected;
  final bool isDark;

  const XpTimeRangeSelector({
    super.key,
    required this.selectedPeriod,
    required this.onSelected,
    required this.isDark,
  });

  static const List<({AnalyticsPeriod period, String label, IconData icon})>
      _options = [
    (period: AnalyticsPeriod.today, label: 'Today', icon: Icons.today_outlined),
    (period: AnalyticsPeriod.week, label: 'Week', icon: Icons.view_week_outlined),
    (period: AnalyticsPeriod.month, label: 'Month', icon: Icons.calendar_month_outlined),
    (period: AnalyticsPeriod.year, label: 'Year', icon: Icons.calendar_today_outlined),
    (period: AnalyticsPeriod.oneYear, label: 'All Time', icon: Icons.all_inclusive_rounded),
  ];

  String _currentLabel() {
    for (final opt in _options) {
      if (opt.period == selectedPeriod) return opt.label;
    }
    return 'Month';
  }

  void _showPopover(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height + 4,
      offset.dx + size.width,
      offset.dy + size.height + 4,
    );

    final selected = await showMenu<AnalyticsPeriod>(
      context: context,
      position: position,
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      items: [
        for (final opt in _options)
          PopupMenuItem<AnalyticsPeriod>(
            value: opt.period,
            height: 40,
            child: _PopoverItemContent(
              label: opt.label,
              icon: opt.icon,
              isSelected: selectedPeriod == opt.period,
              isDark: isDark,
            ),
          ),
      ],
    );

    if (selected != null && selected != selectedPeriod) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : KratosTheme.lightTextPrimary;

    return InkWell(
      onTap: () => _showPopover(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x1F0F172A),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 14.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 7),
            Text(
              _currentLabel(),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopoverItemContent extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;

  const _PopoverItemContent({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lime = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0x22EEFF08) : const Color(0x1F658F00))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected ? lime : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? lime : const Color(0xFF4E7100)) : primary,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 16,
              color: lime,
            ),
        ],
      ),
    );
  }
}
