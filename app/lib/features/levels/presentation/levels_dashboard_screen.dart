import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_tiers.dart';
import '../../../app/kratos_visuals.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../data/drift/app_database.dart';
import '../../life_areas/presentation/life_area_dashboard_screen.dart';
import '../../life_areas/presentation/life_areas_screen.dart';
import '../../progression/data/overall_progression_repository.dart';
import '../../progression/domain/global_progression.dart';
import '../data/levels_dashboard_repository.dart';

/// KRATOS Levels Screen — The Overall Progression Center.
///
/// Communicates:
/// 1. Current Overall Level
/// 2. Current Overall Tier
/// 3. Total Overall XP
/// 4. Progress toward next level
/// 5. Distribution of XP across Life Areas (sorted highest to lowest)
class LevelsDashboardScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Stream<List<LevelsDashboardEntry>>? entriesStream;
  final Stream<OverallProgressionSnapshot>? overallStream;

  const LevelsDashboardScreen({
    super.key,
    required this.database,
    required this.ownerId,
    this.entriesStream,
    this.overallStream,
  });

  @override
  State<LevelsDashboardScreen> createState() => _LevelsDashboardScreenState();
}

class _LevelsDashboardScreenState extends State<LevelsDashboardScreen> {
  late final LevelsDashboardRepository _repository;
  late Stream<List<LevelsDashboardEntry>> _entriesStream;
  late Stream<OverallProgressionSnapshot> _overallStream;
  bool _errorLogged = false;

  @override
  void initState() {
    super.initState();
    _repository = LevelsDashboardRepository(widget.database);
    _entriesStream =
        widget.entriesStream ?? _repository.watchProgressions(widget.ownerId);
    _overallStream =
        widget.overallStream ??
        OverallProgressionRepository(widget.database).watch(widget.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KratosTheme.volcanic,
      appBar: AppBar(
        title: const Text(
          'LEVELS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          StreamBuilder<List<LevelsDashboardEntry>>(
            stream: _entriesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _logError(snapshot.error, snapshot.stackTrace);
                return _ErrorState(onRetry: _reload);
              }
              if (!snapshot.hasData) {
                return const _LoadingState();
              }

              final entries = snapshot.data!;
              final sortedEntries = List<LevelsDashboardEntry>.from(entries)
                ..sort(
                  (a, b) =>
                      b.progression.totalXp.compareTo(a.progression.totalXp),
                );

              return StreamBuilder<OverallProgressionSnapshot>(
                stream: _overallStream,
                builder: (context, overallSnapshot) {
                  if (overallSnapshot.hasError) {
                    _logError(
                      overallSnapshot.error,
                      overallSnapshot.stackTrace,
                    );
                    return _ErrorState(onRetry: _reload);
                  }
                  if (!overallSnapshot.hasData) {
                    return const _LoadingState();
                  }
                  final global = overallSnapshot.data!.global;
                  return _ProgressionContent(
                    globalProgression: global,
                    sortedEntries: sortedEntries,
                    overallXp: global.overallXp,
                    onAreaTap: _openDetail,
                    onCreateArea: _openLifeAreas,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _logError(Object? error, StackTrace? stackTrace) {
    if (_errorLogged) return;
    _errorLogged = true;
    developer.log(
      'Levels dashboard failed to load',
      name: 'kratos.levels',
      error: error,
      stackTrace: stackTrace,
    );
    if (error != null) TelemetryService().recordError(error, stackTrace);
  }

  void _reload() {
    setState(() {
      _errorLogged = false;
      _entriesStream = _repository.watchProgressions(widget.ownerId);
      _overallStream = OverallProgressionRepository(widget.database)
          .watch(widget.ownerId);
    });
  }

  void _openDetail(LevelsDashboardEntry entry) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: LifeAreaDashboardScreen(
          database: widget.database,
          ownerId: widget.ownerId,
          area: entry.area,
        ),
      ),
    );
  }

  void _openLifeAreas() {
    Navigator.of(context).push(
      KratosPageRoute(
        page: LifeAreasScreen(
          database: widget.database,
          ownerId: widget.ownerId,
        ),
      ),
    );
  }
}

/// The main scrollable content layout of the Progression Center.
class _ProgressionContent extends StatelessWidget {
  final GlobalProgressionState globalProgression;
  final List<LevelsDashboardEntry> sortedEntries;
  final int overallXp;
  final ValueChanged<LevelsDashboardEntry> onAreaTap;
  final VoidCallback onCreateArea;

  const _ProgressionContent({
    required this.globalProgression,
    required this.sortedEntries,
    required this.overallXp,
    required this.onAreaTap,
    required this.onCreateArea,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // Section Eyebrow
            const Text(
              'OVERALL PROGRESSION CENTER',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 14),

            // Top Primary Liquid Glass Card: Overall Progression
            _OverallProgressionCard(progression: globalProgression),

            const SizedBox(height: 32),

            // Life Area Distribution Header Row
            Row(
              children: [
                const Text(
                  'LIFE AREA DISTRIBUTION',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sortedEntries.length} ${sortedEntries.length == 1 ? 'AREA' : 'AREAS'}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Responsive Distribution Cards Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                if (sortedEntries.isEmpty) {
                  return _EmptyDistribution(onCreate: onCreateArea);
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in sortedEntries)
                      SizedBox(
                        width: cardWidth,
                        child: _LifeAreaDistributionCard(
                          entry: entry,
                          overallXp: overallXp,
                          onTap: () => onAreaTap(entry),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDistribution extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyDistribution({required this.onCreate});

  @override
  Widget build(BuildContext context) => KratosGlassCard(
    dashboardGlass: true,
    borderRadius: BorderRadius.circular(18),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Create a Life Area to see its share of your overall progression.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: onCreate, child: const Text('Create')),
      ],
    ),
  );
}

/// Large Primary Liquid Glass Card communicating Overall Level, Tier, XP, and Progress.
class _OverallProgressionCard extends StatelessWidget {
  final GlobalProgressionState progression;

  const _OverallProgressionCard({required this.progression});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final level = progression.currentLevel;
    final tierColor = KratosTierSystem.getGlobalColor(level.name);

    return KratosGlassCard(
      dashboardGlass: true,
      accentColor: tierColor,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Section Label + Tier Pill Badge
          Row(
            children: [
              const Text(
                'OVERALL PROGRESSION',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.36),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      KratosTierSystem.getGlobalIcon(level.name),
                      size: 14,
                      color: tierColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      level.name.toUpperCase(),
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current Overall Level Prominently
          Text(
            '${level.name.toUpperCase()} ${level.romanNumeral}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          // Total Overall XP and Percentage Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                progression.nextLevel == null
                    ? '${formatter.format(level.xpThreshold)}+ XP'
                    : '${formatter.format(progression.overallXp)} XP',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${progression.progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: tierColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Clean Liquid Glass Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.08),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  end: (progression.progressPercent / 100.0).clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tierColor.withValues(alpha: 0.8), tierColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Progress toward next level
          Row(
            children: [
              const Icon(
                Icons.north_east_rounded,
                size: 13,
                color: Colors.white38,
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  progression.nextLevel == null
                      ? 'Maximum level reached'
                      : '${formatter.format(progression.xpToNextLevel)} XP to Level ${progression.nextLevel!.romanNumeral}',
                  key: ValueKey(progression.nextLevel?.levelNumber),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Life Area Distribution Item Card.
class _LifeAreaDistributionCard extends StatelessWidget {
  final LevelsDashboardEntry entry;
  final int overallXp;
  final VoidCallback onTap;

  const _LifeAreaDistributionCard({
    required this.entry,
    required this.overallXp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final areaTierColor = KratosTierSystem.getColor(
      entry.progression.tier,
      entry.progression.tierColor,
    );
    final pct = overallXp > 0
        ? (entry.progression.totalXp / overallXp * 100.0)
        : 0.0;

    return KratosSpringCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      glowColor: areaTierColor,
      child: KratosGlassCard(
        dashboardGlass: true,
        accentColor: areaTierColor,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Life Area Name + Percentage Badge + Chevron
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.area.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: KratosTheme.acidLime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: KratosTheme.acidLime.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: KratosTheme.acidLime,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Row: Current Life Area Level & Tier + XP
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      KratosTierSystem.getIcon(entry.progression.tier),
                      size: 13,
                      color: areaTierColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LEVEL ${entry.progression.level} · ${entry.progression.tier.toUpperCase()}',
                      style: TextStyle(
                        color: areaTierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${formatter.format(entry.progression.totalXp)} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal Distribution Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 5,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.06),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: areaTierColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: areaTierColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
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

/// Loading state wrapping the geometry-matched skeleton in KratosShimmer.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const KratosShimmer(child: LevelsDashboardSkeleton());
}

/// Error state offering a retry button.
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: KratosGlassCard(
        dashboardGlass: true,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white38,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load Levels.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            KratosSpringCard(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: KratosTheme.acidLime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Color(0xFF0D0D0D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

