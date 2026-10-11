import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';
import '../../../data/drift/app_database.dart';
import '../data/analytics_mock_data.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';
import 'insights_screen.dart';
import 'widgets/analytics_daily_activity_card.dart';
import 'widgets/analytics_kpi_cards.dart';
import 'widgets/analytics_life_areas_overview_card.dart';
import 'widgets/analytics_top_skills_card.dart';
import 'widgets/analytics_xp_distribution_card.dart';
import 'widgets/analytics_xp_progress_card.dart';
import 'widgets/analytics_xp_trend_card.dart';
import 'widgets/consistency_floating_detail.dart';
import 'widgets/focus_time/analytics_focus_time_section.dart';

/// KRATOS Analytics Screen — Wave 02 Foundation.
///
/// Scope strictly restricted to:
/// - Transparent, non-obtrusive page structure sitting atop the fixed KRATOS environment
/// - Analytics section heading, 3-bar identity icon, and supporting copy
/// - Responsive controls foundation:
///     1. Date Range selector (7D, 30D, 90D, Year, All Time)
///     2. Life Area filter (All Life Areas + dynamic life areas)
///     3. Source filter (All Sources, Tasks, Goals, Projects, Activities, Skills)
///     4. Time Period / Granularity segmented toggle (Day, Week, Month, Year)
/// - Empty content body below the filter row (cards/charts deferred to future waves)
class AnalyticsScreen extends StatefulWidget {
  final String? ownerId;
  final AppDatabase? database;
  final AnalyticsRepository? repository;
  final ValueChanged<AnalyticsPeriod>? onPeriodChanged;
  final ValueChanged<String?>? onLifeAreaChanged;
  final ValueChanged<String?>? onSourceChanged;
  final ValueChanged<String>? onGranularityChanged;
  final AnalyticsPeriod initialPeriod;
  final String? initialLifeAreaId;
  final String? initialSource;
  final String initialGranularity;

  const AnalyticsScreen({
    super.key,
    this.ownerId,
    this.database,
    this.repository,
    this.onPeriodChanged,
    this.onLifeAreaChanged,
    this.onSourceChanged,
    this.onGranularityChanged,
    this.initialPeriod = AnalyticsPeriod.thirtyDays,
    this.initialLifeAreaId,
    this.initialSource,
    this.initialGranularity = 'Month',
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late AnalyticsPeriod _selectedPeriod;
  late String? _selectedLifeAreaId;
  late String? _selectedSource;
  late String _selectedGranularity;
  bool _showConsistencyDetail = false;
  bool _isLoading = false;
  bool _isNavigatingInsights = false;

  void _openInsightsScreen(AnalyticsSnapshot snapshot) {
    if (_isNavigatingInsights) return;
    _isNavigatingInsights = true;
    Navigator.of(context).push(
      KratosPageRoute(
        page: InsightsScreen(
          snapshot: snapshot,
          ownerId: widget.ownerId,
          database: widget.database,
          selectedPeriod: _selectedPeriod,
          periodSubtitle: _selectedPeriod.comparisonLabel,
        ),
        settings: const RouteSettings(name: '/insights'),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isNavigatingInsights = false);
      }
    });
  }

  List<({String id, String name})> _lifeAreas = const [];
  AnalyticsSnapshot? _snapshot;

  static const List<({String id, String name})> _fallbackLifeAreas = [
    (id: 'la_health', name: 'Physical Health'),
    (id: 'la_career', name: 'Career & Wealth'),
    (id: 'la_mind', name: 'Knowledge & Mind'),
    (id: 'la_relationships', name: 'Relationships'),
    (id: 'la_inner_peace', name: 'Inner Peace'),
  ];

  static const List<({String? value, String label, IconData icon})>
  _sourceOptions = [
    (value: null, label: 'All Sources', icon: Icons.tune_rounded),
    (value: 'task', label: 'Tasks', icon: Icons.checklist_rounded),
    (value: 'goal', label: 'Goals', icon: Icons.track_changes_rounded),
    (value: 'project', label: 'Projects', icon: Icons.account_tree_outlined),
    (value: 'activity', label: 'Activities', icon: Icons.repeat_rounded),
    (value: 'skill', label: 'Skills', icon: Icons.military_tech_outlined),
  ];

  static const List<({AnalyticsPeriod value, String label})> _periodOptions = [
    (value: AnalyticsPeriod.sevenDays, label: 'Last 7 Days'),
    (value: AnalyticsPeriod.thirtyDays, label: 'Last 30 Days'),
    (value: AnalyticsPeriod.ninetyDays, label: 'Last 90 Days'),
    (value: AnalyticsPeriod.year, label: 'This Year'),
    (value: AnalyticsPeriod.oneYear, label: 'All Time'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _selectedLifeAreaId = widget.initialLifeAreaId;
    _selectedSource = widget.initialSource;
    _selectedGranularity = widget.initialGranularity;
    _loadLifeAreas();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final ownerId = widget.ownerId ?? 'usr_seed_dev_01';
    final repo = widget.repository ?? AnalyticsRepository(widget.database);
    final range = AnalyticsDateRange.forPeriod(_selectedPeriod);
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final snap = await repo
          .load(
            ownerId: ownerId,
            range: range,
            lifeAreaId: _selectedLifeAreaId,
            sourceType: _selectedSource,
          )
          .timeout(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _snapshot = AnalyticsMockData.snapshot(
            range: range,
            lifeAreaId: _selectedLifeAreaId,
            sourceType: _selectedSource,
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLifeAreas() async {
    final ownerId = widget.ownerId ?? 'usr_seed_dev_01';
    final repo = widget.repository ?? AnalyticsRepository(widget.database);
    try {
      final areas = await repo
          .listLifeAreas(ownerId)
          .timeout(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _lifeAreas = areas.isNotEmpty ? areas : _fallbackLifeAreas;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lifeAreas = _fallbackLifeAreas;
        });
      }
    }
  }

  String _periodLabel(AnalyticsPeriod period) {
    for (final opt in _periodOptions) {
      if (opt.value == period) return opt.label;
    }
    return 'Last 30 Days';
  }

  String _lifeAreaLabel(String? id) {
    if (id == null) return 'All Life Areas';
    for (final area in _lifeAreas) {
      if (area.id == id) return area.name;
    }
    return 'All Life Areas';
  }

  String _sourceLabel(String? source) {
    for (final opt in _sourceOptions) {
      if (opt.value == source) return opt.label;
    }
    return 'All Sources';
  }

  void _onPeriodSelected(AnalyticsPeriod period) {
    setState(() => _selectedPeriod = period);
    _loadSnapshot();
    widget.onPeriodChanged?.call(period);
  }

  void _onLifeAreaSelected(String? id) {
    setState(() => _selectedLifeAreaId = id);
    _loadSnapshot();
    widget.onLifeAreaChanged?.call(id);
  }

  void _onSourceSelected(String? source) {
    setState(() => _selectedSource = source);
    _loadSnapshot();
    widget.onSourceChanged?.call(source);
  }

  void _onGranularitySelected(String gran) {
    setState(() => _selectedGranularity = gran);
    widget.onGranularityChanged?.call(gran);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile
        ? 16.0
        : (screenWidth < 960 ? 24.0 : 32.0);
    final topPadding = isMobile ? 18.0 : 26.0;

    final activeSnapshot =
        _snapshot ??
        AnalyticsMockData.snapshot(
          range: AnalyticsDateRange.forPeriod(_selectedPeriod),
          lifeAreaId: _selectedLifeAreaId,
          sourceType: _selectedSource,
        );

    final mainContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        32.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── A & B: Heading + Supporting Copy ─────────────────────────
          _AnalyticsHeading(isMobile: isMobile),

          SizedBox(height: isMobile ? 16 : 20),

          // ── Controls & Filters Foundation ────────────────────────────
          _buildControlsRow(context),

          // ── Wave 03: Top 4 KPI Summary Cards Row ─────────────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsKpiSummaryRow(
            snapshot: activeSnapshot,
            periodSubtitle: _selectedPeriod.comparisonLabel,
            onConsistencyTap: () {
              setState(() => _showConsistencyDetail = true);
            },
          ),

          // ── Wave 04: XP Trend Time-Series Section ─────────────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsXpTrendCard(
            snapshot: activeSnapshot,
            periodSubtitle: _selectedPeriod.comparisonLabel,
          ),

          // ── Wave 09: This Week / Daily Activity Section ───────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsDailyActivityCard(
            snapshot: activeSnapshot,
            isLoading: _isLoading,
            periodSubtitle: _selectedPeriod.comparisonLabel,
            lifeAreas: _lifeAreas,
            selectedLifeAreaId: _selectedLifeAreaId,
            onLifeAreaChanged: _onLifeAreaSelected,
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: _onPeriodSelected,
            onRetry: _loadSnapshot,
          ),

          // ── Focus Time Complete Subsystem Section ───────────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsFocusTimeSection(
            snapshot: activeSnapshot.safeFocusTime,
            isLoading: _isLoading,
            periodLabel: _periodLabel(_selectedPeriod),
            periodSubtitle: _selectedPeriod.comparisonLabel,
            fullSnapshot: activeSnapshot,
            onViewAllInsightsTap: () => _openInsightsScreen(activeSnapshot),
          ),

          // ── Wave 05: XP Distribution Section ──────────────────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsXpDistributionCard(
            snapshot: activeSnapshot,
            periodSubtitle: _selectedPeriod.comparisonLabel,
            isLoading: _isLoading,
            onSourceSelected: (source) {
              // Bidirectional selection can optionally sync with filter or highlight
            },
          ),

          // ── Wave 07: Life Areas Overview (Radar / Spider Chart + List) ──
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsLifeAreasOverviewCard(
            snapshot: activeSnapshot,
            isLoading: _isLoading,
            periodSubtitle: _selectedPeriod.label,
            initialFocusedLifeAreaId: _selectedLifeAreaId,
          ),

          // ── Wave 08: Top Skills (Ranked List + Detail) ────────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsTopSkillsCard(
            snapshot: activeSnapshot,
            isLoading: _isLoading,
            periodSubtitle: _selectedPeriod.comparisonLabel,
            lifeAreas: _lifeAreas,
            selectedLifeAreaId: _selectedLifeAreaId,
            onLifeAreaChanged: _onLifeAreaSelected,
            onRetry: _loadSnapshot,
          ),

          // ── Wave 06: XP Progress / Life Area Progression ──────────────
          SizedBox(height: isMobile ? 18 : 22),
          AnalyticsXpProgressCard(
            ownerId: widget.ownerId,
            database: widget.database,
          ),
        ],
      ),
    );

    return Stack(
      children: [
        mainContent,
        if (_showConsistencyDetail)
          ConsistencyFloatingDetail(
            snapshot: activeSnapshot,
            periodLabel: _periodLabel(_selectedPeriod),
            periodSubtitle: _selectedPeriod.comparisonLabel,
            lifeAreaName: _lifeAreaLabel(_selectedLifeAreaId),
            sourceName: _sourceLabel(_selectedSource),
            onClose: () => setState(() => _showConsistencyDetail = false),
          ),
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final dateControl = _AnalyticsDropdownPill<AnalyticsPeriod>(
          icon: Icons.calendar_today_outlined,
          label: _periodLabel(_selectedPeriod),
          selectedValue: _selectedPeriod,
          items: [
            for (final opt in _periodOptions)
              _DropdownItem(
                value: opt.value,
                label: opt.label,
                icon: Icons.calendar_today_outlined,
              ),
          ],
          onSelected: _onPeriodSelected,
        );

        final lifeAreaControl = _AnalyticsDropdownPill<String?>(
          icon: Icons.track_changes_outlined,
          label: _lifeAreaLabel(_selectedLifeAreaId),
          selectedValue: _selectedLifeAreaId,
          items: [
            const _DropdownItem(
              value: null,
              label: 'All Life Areas',
              icon: Icons.track_changes_outlined,
            ),
            for (final area in _lifeAreas)
              _DropdownItem(
                value: area.id,
                label: area.name,
                icon: Icons.adjust_rounded,
              ),
          ],
          onSelected: _onLifeAreaSelected,
        );

        final sourceControl = _AnalyticsDropdownPill<String?>(
          icon: Icons.bar_chart_rounded,
          label: _sourceLabel(_selectedSource),
          selectedValue: _selectedSource,
          items: [
            for (final opt in _sourceOptions)
              _DropdownItem(value: opt.value, label: opt.label, icon: opt.icon),
          ],
          onSelected: _onSourceSelected,
        );

        final segmentedControl = _AnalyticsSegmentedControl(
          selected: _selectedGranularity,
          onChanged: _onGranularitySelected,
          expand: false,
        );

        if (availableWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AnalyticsSegmentedControl(
                selected: _selectedGranularity,
                onChanged: _onGranularitySelected,
                expand: true,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [dateControl, lifeAreaControl, sourceControl],
              ),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [dateControl, lifeAreaControl, sourceControl],
            ),
            segmentedControl,
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANALYTICS HEADER ICON & TYPOGRAPHY
// ─────────────────────────────────────────────────────────────────────────────

/// 3-bar analytical icon matching the master KRATOS visual reference.
class _AnalyticsHeaderIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _AnalyticsHeaderIcon({required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: size * 0.22,
            height: size * 0.65,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
          ),
          SizedBox(width: size * 0.12),
          Container(
            width: size * 0.22,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
          ),
          SizedBox(width: size * 0.12),
          Container(
            width: size * 0.22,
            height: size * 0.45,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsHeading extends StatelessWidget {
  final bool isMobile;

  const _AnalyticsHeading({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : KratosTheme.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: isMobile ? 2 : 4),
          child: _AnalyticsHeaderIcon(
            color: titleColor,
            size: isMobile ? 24 : 28,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Analytics',
                style: TextStyle(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Track your progress, understand your patterns, and optimize your growth.',
                style: TextStyle(
                  fontSize: isMobile ? 12.5 : 13.5,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID GLASS FILTER DROPDOWN CONTROLS
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _DropdownItem({required this.value, required this.label, this.icon});
}

class _AnalyticsDropdownPill<T> extends StatefulWidget {
  final IconData icon;
  final String label;
  final T selectedValue;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T> onSelected;

  const _AnalyticsDropdownPill({
    required this.icon,
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_AnalyticsDropdownPill<T>> createState() =>
      _AnalyticsDropdownPillState<T>();
}

class _AnalyticsDropdownPillState<T> extends State<_AnalyticsDropdownPill<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;

    final bgColor = isDark
        ? (_isHovered ? const Color(0x22FFFFFF) : const Color(0x14FFFFFF))
        : (_isHovered ? const Color(0xE6FFFFFF) : const Color(0xB3FFFFFF));

    final borderColor = isDark
        ? (_isHovered ? const Color(0x38FFFFFF) : const Color(0x24FFFFFF))
        : (_isHovered ? const Color(0x330F172A) : const Color(0x1F0F172A));

    final textColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : KratosTheme.lightTextSecondary;
    final chevronColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : KratosTheme.lightTextSecondary;

    return Theme(
      data: theme.copyWith(
        hoverColor: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F0F172A),
      ),
      child: PopupMenuButton<T>(
        tooltip: '',
        offset: const Offset(0, 42),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F0F172A),
            width: 1.0,
          ),
        ),
        color: isDark ? const Color(0xFF141815) : Colors.white,
        onSelected: widget.onSelected,
        itemBuilder: (context) => [
          for (final item in widget.items)
            PopupMenuItem<T>(
              value: item.value,
              height: 38,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 15,
                      color: item.value == widget.selectedValue
                          ? accent
                          : (isDark
                                ? Colors.white60
                                : KratosTheme.lightTextSecondary),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.value == widget.selectedValue
                            ? (isDark
                                  ? Colors.white
                                  : KratosTheme.lightTextPrimary)
                            : (isDark
                                  ? Colors.white70
                                  : KratosTheme.lightTextSecondary),
                        fontWeight: item.value == widget.selectedValue
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (item.value == widget.selectedValue)
                    Icon(Icons.check_rounded, size: 16, color: accent),
                ],
              ),
            ),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: [
                if (isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                else
                  const BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: iconColor, size: 15),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: chevronColor,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME PERIOD / GRANULARITY SEGMENTED CONTROL
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsSegmentedControl extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool expand;

  const _AnalyticsSegmentedControl({
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final options = const ['Day', 'Week', 'Month', 'Year'];

    final containerBg = isDark
        ? const Color(0x14FFFFFF)
        : const Color(0xB3FFFFFF);
    final containerBorder = isDark
        ? const Color(0x22FFFFFF)
        : const Color(0x1F0F172A);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: containerBorder, width: 1.0),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          else
            const BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final opt in options)
            if (expand)
              Expanded(
                child: _SegmentItem(
                  label: opt,
                  isSelected: opt == selected,
                  isDark: isDark,
                  onTap: () => onChanged(opt),
                ),
              )
            else
              _SegmentItem(
                label: opt,
                isSelected: opt == selected,
                isDark: isDark,
                onTap: () => onChanged(opt),
              ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SegmentItem> createState() => _SegmentItemState();
}

class _SegmentItemState extends State<_SegmentItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.isDark ? const Color(0x2EFFFFFF) : Colors.white;

    final activeTextColor = widget.isDark
        ? Colors.white
        : KratosTheme.lightTextPrimary;

    final inactiveTextColor = widget.isDark
        ? (_isHovered
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.60))
        : (_isHovered
              ? const Color(0xFF1E293B)
              : KratosTheme.lightTextSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: widget.isSelected
                ? [
                    if (widget.isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    else
                      const BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              color: widget.isSelected ? activeTextColor : inactiveTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
