import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../data/xp_progress_repository.dart';
import '../../domain/analytics_models.dart';
import '../../domain/xp_progress_models.dart';
import 'xp_progress/xp_progress_gauge.dart';
import 'xp_progress/xp_progress_level_progression.dart';
import 'xp_progress/xp_progress_level_summary.dart';
import 'xp_progress/xp_progress_metrics.dart';
import 'xp_progress/xp_progress_selectors.dart';
import 'xp_progress/xp_progress_sources.dart';

/// KRATOS Analytics — Wave 06: XP Progress & Life Area Progression Card.
///
/// Features:
/// - Isolated local filter state (Life Area & Time Range) independent from global filters
/// - 270-degree CustomPainter XP gauge with SweepGradient & vector crystal emblem
/// - Vector geometric crystal emblem with multi-angle specular lighting
/// - Real KRATOS domain progression logic via ProgressionCalculator & Drift/Supabase
/// - True Section 7 semantics: specific area uses Level IV — Crystal; All Life Areas uses Portfolio Overview
/// - Responsive composition for Desktop (>= 960px), Tablet (640-959px), and Mobile (< 640px)
/// - Pure black/white/gray aesthetic with restrained Acid Lime (#EEFF08) highlights.
class AnalyticsXpProgressCard extends StatefulWidget {
  final String? ownerId;
  final AppDatabase? database;
  final XpProgressRepository? repository;
  final String? initialLifeAreaId;
  final bool startWithAllAreas;
  final AnalyticsPeriod initialPeriod;

  const AnalyticsXpProgressCard({
    super.key,
    this.ownerId,
    this.database,
    this.repository,
    this.initialLifeAreaId,
    this.startWithAllAreas = false,
    this.initialPeriod = AnalyticsPeriod.month,
  });

  @override
  State<AnalyticsXpProgressCard> createState() =>
      _AnalyticsXpProgressCardState();
}

class _AnalyticsXpProgressCardState extends State<AnalyticsXpProgressCard> {
  late final XpProgressRepository _repository = widget.repository ??
      (widget.database != null
          ? DriftXpProgressRepository(widget.database!)
          : const MockXpProgressRepository());

  late String? _selectedLifeAreaId = widget.initialLifeAreaId;
  late AnalyticsPeriod _selectedPeriod = widget.initialPeriod;

  bool _isLoading = true;
  String? _errorMessage;

  List<({String id, String name})> _lifeAreas = const [];
  XpProgressData? _data;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final ownerId = widget.ownerId ?? 'usr_seed_dev_01';
    try {
      final areas = await _repository.listLifeAreas(ownerId);
      if (mounted) {
        setState(() {
          _lifeAreas = areas;
          // If not configured to start with All Life Areas and no initial area was given, default to first area
          if (!widget.startWithAllAreas && _selectedLifeAreaId == null && areas.isNotEmpty) {
            _selectedLifeAreaId = areas.first.id;
          }
        });
      }
    } catch (_) {
      // Fallback gracefully if listing fails
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    final ownerId = widget.ownerId ?? 'usr_seed_dev_01';
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _repository.load(
        ownerId: ownerId,
        period: _selectedPeriod,
        lifeAreaId: _selectedLifeAreaId,
      );
      if (mounted) {
        setState(() {
          _data = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to calculate progression data.';
          _isLoading = false;
        });
      }
    }
  }

  void _onLifeAreaChanged(String? newId) {
    if (_selectedLifeAreaId == newId) return;
    setState(() => _selectedLifeAreaId = newId);
    _loadData();
  }

  void _onPeriodChanged(AnalyticsPeriod newPeriod) {
    if (_selectedPeriod == newPeriod) return;
    setState(() => _selectedPeriod = newPeriod);
    _loadData();
  }

  String _currentLifeAreaName() {
    if (_selectedLifeAreaId == null) return 'All Life Areas';
    for (final a in _lifeAreas) {
      if (a.id == _selectedLifeAreaId) return a.name;
    }
    return _data?.lifeAreaName ?? 'Life Area';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final isDesktop = cardW >= 960;
        final isTablet = cardW >= 640 && cardW < 960;
        final isMobile = cardW < 640;

        return KratosGlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 22,
            vertical: isMobile ? 18 : 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Header with Title & Independent Selectors ──────────────
              _buildHeader(
                context,
                isDark: isDark,
                isMobile: isMobile,
                primary: primary,
                secondary: secondary,
                lime: lime,
              ),

              SizedBox(height: isMobile ? 16 : 20),

              // ── 2. Content Body (Loading, Error, Empty, or Populated) ──────
              if (_isLoading)
                _buildSkeleton(context, isDark, isMobile)
              else if (_errorMessage != null)
                _buildErrorState(context, secondary, lime)
              else if (_data != null)
                _buildPopulatedContent(
                  context,
                  _data!,
                  isDark: isDark,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                  lime: lime,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required Color primary,
    required Color secondary,
    required Color lime,
  }) {
    final iconBg = isDark ? const Color(0x22EEFF08) : const Color(0x1F658F00);

    final titleWidget = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: lime.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 0.8,
            ),
          ),
          child: Icon(
            Icons.bar_chart_rounded,
            size: 19,
            color: lime,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'XP Progress',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your current XP progress within the selected Life Area.',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: secondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final selectorsWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        XpLifeAreaSelector(
          selectedId: _selectedLifeAreaId,
          selectedName: _currentLifeAreaName(),
          lifeAreas: _lifeAreas,
          onSelected: _onLifeAreaChanged,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        XpTimeRangeSelector(
          selectedPeriod: _selectedPeriod,
          onSelected: _onPeriodChanged,
          isDark: isDark,
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: selectorsWidget,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: 12),
        selectorsWidget,
      ],
    );
  }

  Widget _buildPopulatedContent(
    BuildContext context,
    XpProgressData data, {
    required bool isDark,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
    required Color lime,
  }) {
    final gauge = XpProgressGauge(
      progress: data.progressPercent / 100.0,
      levelText: data.isAllLifeAreas ? 'ALL LIFE AREAS' : 'LEVEL ${data.levelRoman}',
      xpFractionText: data.isAllLifeAreas
          ? '${_formatNumber(data.periodXp)} XP in Period'
          : '${_formatNumber(data.currentXp)} / ${_formatNumber(data.targetXp)} XP',
      percentText: '${data.progressPercent.round()}%',
      subtitleText: data.isAllLifeAreas
          ? 'Across all Life Areas'
          : '${_formatNumber(data.remainingXp)} XP to next level',
      isDark: isDark,
      accentColor: lime,
      isAllLifeAreas: data.isAllLifeAreas,
    );

    final levelSummary = XpProgressLevelSummary(
      isAllLifeAreas: data.isAllLifeAreas,
      levelRoman: data.levelRoman,
      tierName: data.tierName,
      tierDescription: data.tierDescription,
      canPromote: data.canPromote,
      activeLifeAreasCount: data.activeLifeAreasCount,
      topLifeAreaName: data.topLifeAreaName,
      isDark: isDark,
      accentColor: lime,
    );

    final metrics = XpProgressMetrics(
      currentXp: data.currentXp,
      periodDelta: data.periodDelta,
      periodComparisonLabel: data.period.comparisonLabel,
      remainingXp: data.remainingXp,
      progressPercent: data.progressPercent,
      totalHistoricalXp: data.totalHistoricalXp,
      lifeAreaName: data.lifeAreaName,
      isAllLifeAreas: data.isAllLifeAreas,
      isDark: isDark,
      accentColor: lime,
    );

    final progression = XpProgressLevelProgression(
      milestones: data.milestones,
      lifeAreaName: data.lifeAreaName,
      isAllLifeAreas: data.isAllLifeAreas,
      isDark: isDark,
      accentColor: lime,
    );

    final sources = XpProgressSources(
      sources: data.sources,
      isDark: isDark,
      accentColor: lime,
    );

    if (isDesktop) {
      // ── DESKTOP 2-COLUMN COMPOSITION (Matching Reference) ─────────────────
      return Column(
        children: [
          // Top Row: Left Gauge, Right Column (Summary + Metrics)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Gauge
              SizedBox(
                width: 320,
                child: gauge,
              ),
              const SizedBox(width: 20),

              // Right Column: Level Summary + Metrics
              Expanded(
                child: Column(
                  children: [
                    levelSummary,
                    const SizedBox(height: 14),
                    metrics,
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Bottom Row: Left Progression, Right Sources
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: progression),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: sources),
            ],
          ),
        ],
      );
    }

    if (isTablet) {
      // ── TABLET COMPOSITION ───────────────────────────────────────────────
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 260, child: gauge),
              const SizedBox(width: 16),
              Expanded(child: levelSummary),
            ],
          ),
          const SizedBox(height: 16),
          metrics,
          const SizedBox(height: 16),
          progression,
          const SizedBox(height: 16),
          sources,
        ],
      );
    }

    // ── MOBILE SINGLE-COLUMN COMPOSITION ────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: gauge),
        const SizedBox(height: 16),
        levelSummary,
        const SizedBox(height: 14),
        metrics,
        const SizedBox(height: 14),
        progression,
        const SizedBox(height: 14),
        sources,
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context, bool isDark, bool isMobile) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Color secondary, Color lime) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFFF5252)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load progression data.',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh_rounded, size: 16, color: lime),
              label: Text('Retry', style: TextStyle(color: lime)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: lime.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}
