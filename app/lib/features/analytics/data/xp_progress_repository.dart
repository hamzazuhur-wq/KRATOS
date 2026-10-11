import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../progression/domain/progression_calculator.dart';
import '../domain/analytics_models.dart';
import '../domain/xp_progress_models.dart';

abstract class XpProgressRepository {
  Future<List<({String id, String name})>> listLifeAreas(String ownerId);

  Future<XpProgressData> load({
    required String ownerId,
    required AnalyticsPeriod period,
    String? lifeAreaId,
  });
}

class DriftXpProgressRepository implements XpProgressRepository {
  final AppDatabase _db;

  const DriftXpProgressRepository(this._db);

  @override
  Future<List<({String id, String name})>> listLifeAreas(String ownerId) async {
    final rows = await (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm.asc(a.sortOrder),
            (a) => OrderingTerm.asc(a.name),
          ]))
        .get();

    return rows.map((r) => (id: r.id, name: r.name)).toList();
  }

  @override
  Future<XpProgressData> load({
    required String ownerId,
    required AnalyticsPeriod period,
    String? lifeAreaId,
  }) async {
    final range = AnalyticsDateRange.forPeriod(period);
    final startUtc = range.startUtc;
    final endUtc = range.endUtc;
    final prevStartUtc = range.previousRange.startUtc;
    final prevEndUtc = range.previousRange.endUtc;

    // Fetch all life areas for owner
    final allLifeAreas = await (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();

    final areaMap = {for (final a in allLifeAreas) a.id: a.name};

    if (lifeAreaId != null) {
      // ───────────────────────────────────────────────────────────────────────
      // SPECIFIC LIFE AREA: Uses ProgressionCalculator (Real Domain Logic)
      // ───────────────────────────────────────────────────────────────────────
      final lifeAreaName = areaMap[lifeAreaId] ?? 'Life Area';

      // 1. Calculate All-Time Lifetime XP allocated to this life area
      final allTimeAllocQuery = _db.select(_db.xpAllocationLines).join([
        innerJoin(
          _db.xpLedger,
          _db.xpLedger.id.equalsExp(_db.xpAllocationLines.ledgerId),
        ),
      ])
        ..where(
          _db.xpLedger.ownerId.equals(ownerId) &
              _db.xpAllocationLines.lifeAreaId.equals(lifeAreaId),
        );
      final allTimeAllocRows = await allTimeAllocQuery.get();

      var areaTotalXp = 0;
      for (final r in allTimeAllocRows) {
        final line = r.readTable(_db.xpAllocationLines);
        areaTotalXp += line.allocatedPoints;
      }

      // 2. Compute canonical Progression via ProgressionCalculator
      final progression = ProgressionCalculator.calculate(
        totalXp: areaTotalXp,
        lifeAreaId: Id(lifeAreaId),
      );

      // 3. Period XP & Previous Period XP
      var periodXp = 0;
      var prevPeriodXp = 0;
      final sourceXpMap = <String, int>{
        'Tasks': 0,
        'Projects': 0,
        'Sessions': 0,
        'Goals': 0,
        'Activities': 0,
        'Other': 0,
      };

      for (final r in allTimeAllocRows) {
        final line = r.readTable(_db.xpAllocationLines);
        final ledger = r.readTable(_db.xpLedger);

        if (ledger.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(endUtc)) {
          periodXp += line.allocatedPoints;

          final category = _mapSourceCategory(ledger.sourceType);
          sourceXpMap[category] =
              (sourceXpMap[category] ?? 0) + line.allocatedPoints;
        } else if (ledger.createdAt.isAfter(prevStartUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(prevEndUtc)) {
          prevPeriodXp += line.allocatedPoints;
        }
      }

      final periodDelta = MetricDelta.compute(
        current: periodXp.toDouble(),
        previous: prevPeriodXp.toDouble(),
      );

      final milestones = _buildMilestones(areaTotalXp, progression.tier);
      final sources = _buildSourceMetrics(sourceXpMap, periodXp);

      return XpProgressData(
        lifeAreaId: lifeAreaId,
        lifeAreaName: lifeAreaName,
        period: period,
        isAllLifeAreas: false,
        currentXp: progression.xpInLevel,
        targetXp: progression.xpToNext > 0 ? progression.xpToNext : 1000,
        progressPercent: progression.progressPct,
        remainingXp: math.max(0, progression.xpToNext - progression.xpInLevel),
        totalHistoricalXp: areaTotalXp,
        periodXp: periodXp,
        periodDelta: periodDelta,
        levelNumber: progression.level,
        levelRoman: _toRoman(progression.level),
        tierName: progression.tier,
        tierDescription: _tierDescription(progression.tier),
        canPromote: progression.canPromote,
        milestones: milestones,
        sources: sources,
      );
    } else {
      // ───────────────────────────────────────────────────────────────────────
      // ALL LIFE AREAS: Aggregate Portfolio Overview (Section 7 Semantics)
      // ───────────────────────────────────────────────────────────────────────
      final allAllocQuery = _db.select(_db.xpAllocationLines).join([
        innerJoin(
          _db.xpLedger,
          _db.xpLedger.id.equalsExp(_db.xpAllocationLines.ledgerId),
        ),
      ])..where(_db.xpLedger.ownerId.equals(ownerId));
      final allAllocRows = await allAllocQuery.get();

      var allTimeTotalXp = 0;
      var periodXp = 0;
      var prevPeriodXp = 0;
      final areaXpBreakdown = <String, int>{};
      final sourceXpMap = <String, int>{
        'Tasks': 0,
        'Projects': 0,
        'Sessions': 0,
        'Goals': 0,
        'Activities': 0,
        'Other': 0,
      };

      for (final r in allAllocRows) {
        final line = r.readTable(_db.xpAllocationLines);
        final ledger = r.readTable(_db.xpLedger);

        allTimeTotalXp += line.allocatedPoints;

        if (ledger.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(endUtc)) {
          periodXp += line.allocatedPoints;
          areaXpBreakdown[line.lifeAreaId] =
              (areaXpBreakdown[line.lifeAreaId] ?? 0) + line.allocatedPoints;

          final category = _mapSourceCategory(ledger.sourceType);
          sourceXpMap[category] =
              (sourceXpMap[category] ?? 0) + line.allocatedPoints;
        } else if (ledger.createdAt.isAfter(prevStartUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(prevEndUtc)) {
          prevPeriodXp += line.allocatedPoints;
        }
      }

      final periodDelta = MetricDelta.compute(
        current: periodXp.toDouble(),
        previous: prevPeriodXp.toDouble(),
      );

      // Top domain in this period
      String? topAreaName;
      if (areaXpBreakdown.isNotEmpty) {
        final topEntry = areaXpBreakdown.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        topAreaName = areaMap[topEntry.key] ?? 'Primary Domain';
      }

      final sources = _buildSourceMetrics(sourceXpMap, periodXp);
      final aggregateProgress = prevPeriodXp > 0
          ? ((periodXp / prevPeriodXp) * 100.0).clamp(0.0, 100.0)
          : (periodXp > 0 ? 85.0 : 0.0);

      final milestones = _buildMilestones(allTimeTotalXp, 'Portfolio');

      return XpProgressData(
        lifeAreaId: null,
        lifeAreaName: 'All Life Areas',
        period: period,
        isAllLifeAreas: true,
        currentXp: periodXp,
        targetXp: prevPeriodXp > 0 ? prevPeriodXp : (periodXp > 0 ? periodXp : 1000),
        progressPercent: double.parse(aggregateProgress.toStringAsFixed(1)),
        remainingXp: math.max(0, (prevPeriodXp > periodXp ? prevPeriodXp - periodXp : 0)),
        totalHistoricalXp: allTimeTotalXp,
        periodXp: periodXp,
        periodDelta: periodDelta,
        levelNumber: 0,
        levelRoman: 'ALL',
        tierName: 'Portfolio',
        tierDescription:
            'Aggregate performance across all active Life Areas.',
        canPromote: true,
        milestones: milestones,
        sources: sources,
        activeLifeAreasCount: allLifeAreas.length,
        topLifeAreaName: topAreaName,
      );
    }
  }

  static String _mapSourceCategory(String sourceType) {
    return switch (sourceType.toLowerCase()) {
      'task' => 'Tasks',
      'project' => 'Projects',
      'session' => 'Sessions',
      'activity' => 'Activities',
      'goal' => 'Goals',
      'skill' => 'Activities',
      _ => 'Other',
    };
  }

  static List<XpSourceMetric> _buildSourceMetrics(
    Map<String, int> sourceXpMap,
    int totalPeriodXp,
  ) {
    const icons = {
      'Tasks': Icons.check_box_outlined,
      'Projects': Icons.folder_outlined,
      'Sessions': Icons.access_time_rounded,
      'Goals': Icons.track_changes_outlined,
      'Activities': Icons.bolt_rounded,
      'Other': Icons.more_horiz_rounded,
    };

    final list = <XpSourceMetric>[];
    for (final entry in sourceXpMap.entries) {
      final xp = entry.value;
      final pct = totalPeriodXp > 0
          ? ((xp / totalPeriodXp) * 100.0).clamp(0.0, 100.0)
          : 0.0;
      list.add(
        XpSourceMetric(
          name: entry.key,
          icon: icons[entry.key] ?? Icons.bubble_chart_outlined,
          xp: xp,
          percent: double.parse(pct.toStringAsFixed(1)),
        ),
      );
    }

    list.sort((a, b) => b.xp.compareTo(a.xp));
    return list;
  }

  static List<XpProgressMilestone> _buildMilestones(
    int totalXp,
    String activeTier,
  ) {
    const definitions = [
      (ordinal: 1, roman: 'I', tier: 'Bronze', entry: 1000),
      (ordinal: 2, roman: 'II', tier: 'Silver', entry: 3000),
      (ordinal: 3, roman: 'III', tier: 'Gold', entry: 7000),
      (ordinal: 4, roman: 'IV', tier: 'Crystal', entry: 15000),
      (ordinal: 5, roman: 'V', tier: 'Diamond', entry: 30000),
    ];

    final currentOrdinal = switch (activeTier.toLowerCase()) {
      'wood' => 0,
      'bronze' => 1,
      'silver' => 2,
      'gold' => 3,
      'crystal' => 4,
      'diamond' => 5,
      'mythic' => 6,
      _ => 4,
    };

    return definitions.map((d) {
      final isCurrent = d.ordinal == currentOrdinal;
      final isCompleted = d.ordinal < currentOrdinal || totalXp >= d.entry;
      final isLocked = d.ordinal > currentOrdinal;

      return XpProgressMilestone(
        ordinal: d.ordinal,
        roman: d.roman,
        tierName: d.tier,
        entryXp: d.entry,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
        isLocked: isLocked,
      );
    }).toList();
  }

  static String _tierDescription(String tier) {
    return switch (tier.toLowerCase()) {
      'wood' => 'Groundwork: develop primary discipline & daily routines.',
      'bronze' => 'Initiation: consistent execution and focus.',
      'silver' => 'Momentum: building operational velocity & habits.',
      'gold' => 'Mastery: high standard of execution & impact.',
      'crystal' => 'Higher focus, greater consistency.',
      'diamond' => 'Excellence: compound capability & depth.',
      'mythic' => 'Transcendence: optimal operating performance.',
      _ => 'Consistent progression within domain.',
    };
  }

  static String _toRoman(int number) {
    if (number <= 0) return 'I';
    const romanMap = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    final buffer = StringBuffer();
    var n = number;
    for (final entry in romanMap.entries) {
      while (n >= entry.key) {
        buffer.write(entry.value);
        n -= entry.key;
      }
    }
    return buffer.toString();
  }
}

/// Mock repository preserved for preview, storybook, and detached widget tests.
class MockXpProgressRepository implements XpProgressRepository {
  final bool shouldFail;
  final bool isEmpty;
  final String? overrideTier;
  final int? overrideLevel;
  final String? overrideRoman;
  final double? overrideProgress;

  const MockXpProgressRepository({
    this.shouldFail = false,
    this.isEmpty = false,
    this.overrideTier,
    this.overrideLevel,
    this.overrideRoman,
    this.overrideProgress,
  });

  static const _mockAreas = [
    (id: 'la_prof', name: 'Professional'),
    (id: 'la_health', name: 'Health & Vitality'),
    (id: 'la_mind', name: 'Mindset & Focus'),
    (id: 'la_sport', name: 'Sport & Athleticism'),
    (id: 'la_finance', name: 'Wealth & Finance'),
  ];

  @override
  Future<List<({String id, String name})>> listLifeAreas(String ownerId) {
    return Future.value(_mockAreas);
  }

  @override
  Future<XpProgressData> load({
    required String ownerId,
    required AnalyticsPeriod period,
    String? lifeAreaId,
  }) {
    if (shouldFail) {
      return Future.error(
        Exception('Failed to load progression data. Connection timeout or ledger desync.'),
      );
    }

    if (isEmpty) {
      return Future.value(
        XpProgressData(
          lifeAreaId: lifeAreaId,
          lifeAreaName: lifeAreaId != null ? 'New Domain' : 'All Life Areas',
          period: period,
          isAllLifeAreas: lifeAreaId == null,
          currentXp: 0,
          targetXp: 1000,
          progressPercent: 0.0,
          remainingXp: 1000,
          totalHistoricalXp: 0,
          periodXp: 0,
          periodDelta: const MetricDelta(
            current: 0,
            previous: 0,
            changePct: 0.0,
            isPositive: true,
          ),
          levelNumber: lifeAreaId != null ? 1 : 0,
          levelRoman: lifeAreaId != null ? 'I' : 'ALL',
          tierName: lifeAreaId != null ? 'Wood' : 'Portfolio',
          tierDescription: lifeAreaId != null
              ? 'Groundwork: develop primary discipline & daily routines.'
              : 'Aggregate view across newly created life areas.',
          canPromote: false,
          activeLifeAreasCount: 1,
          milestones: const [
            XpProgressMilestone(
              ordinal: 1,
              roman: 'I',
              tierName: 'Wood',
              entryXp: 0,
              isCompleted: false,
              isCurrent: true,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 2,
              roman: 'II',
              tierName: 'Bronze',
              entryXp: 1000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
            XpProgressMilestone(
              ordinal: 3,
              roman: 'III',
              tierName: 'Silver',
              entryXp: 3000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
            XpProgressMilestone(
              ordinal: 4,
              roman: 'IV',
              tierName: 'Gold',
              entryXp: 7000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
            XpProgressMilestone(
              ordinal: 5,
              roman: 'V',
              tierName: 'Crystal',
              entryXp: 15000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
          ],
          sources: const [],
        ),
      );
    }

    if (overrideTier == 'Diamond') {
      return Future.value(
        XpProgressData(
          lifeAreaId: lifeAreaId ?? 'la_prof',
          lifeAreaName: 'Professional',
          period: period,
          isAllLifeAreas: false,
          currentXp: 28400,
          targetXp: 30000,
          progressPercent: overrideProgress ?? 94.6,
          remainingXp: 1600,
          totalHistoricalXp: 58400,
          periodXp: 28400,
          periodDelta: const MetricDelta(
            current: 28400,
            previous: 24200,
            changePct: 17.3,
            isPositive: true,
          ),
          levelNumber: overrideLevel ?? 5,
          levelRoman: overrideRoman ?? 'V',
          tierName: 'Diamond',
          tierDescription: 'Excellence: compound capability & depth.',
          canPromote: true,
          milestones: const [
            XpProgressMilestone(
              ordinal: 1,
              roman: 'I',
              tierName: 'Bronze',
              entryXp: 1000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 2,
              roman: 'II',
              tierName: 'Silver',
              entryXp: 3000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 3,
              roman: 'III',
              tierName: 'Gold',
              entryXp: 7000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 4,
              roman: 'IV',
              tierName: 'Crystal',
              entryXp: 15000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 5,
              roman: 'V',
              tierName: 'Diamond',
              entryXp: 30000,
              isCompleted: true,
              isCurrent: true,
              isLocked: false,
            ),
          ],
          sources: const [
            XpSourceMetric(
              name: 'Tasks',
              icon: Icons.check_box_outlined,
              xp: 11200,
              percent: 39.4,
            ),
            XpSourceMetric(
              name: 'Projects',
              icon: Icons.folder_outlined,
              xp: 7600,
              percent: 26.8,
            ),
            XpSourceMetric(
              name: 'Sessions',
              icon: Icons.access_time_rounded,
              xp: 4900,
              percent: 17.3,
            ),
            XpSourceMetric(
              name: 'Goals',
              icon: Icons.track_changes_outlined,
              xp: 3200,
              percent: 11.3,
            ),
            XpSourceMetric(
              name: 'Activities',
              icon: Icons.bolt_rounded,
              xp: 1500,
              percent: 5.2,
            ),
          ],
        ),
      );
    }

    if (lifeAreaId != null) {
      // Return representative realistic data matching ProgressionCalculator output
      return Future.value(
        XpProgressData(
          lifeAreaId: lifeAreaId,
          lifeAreaName: 'Professional',
          period: period,
          isAllLifeAreas: false,
          currentXp: 2450,
          targetXp: 3000,
          progressPercent: 81.7,
          remainingXp: 550,
          totalHistoricalXp: 24580,
          periodXp: 2450,
          periodDelta: const MetricDelta(
            current: 2450,
            previous: 2178,
            changePct: 12.5,
            isPositive: true,
          ),
          levelNumber: 4,
          levelRoman: 'IV',
          tierName: 'Crystal',
          tierDescription: 'Higher focus, greater consistency.',
          canPromote: true,
          milestones: const [
            XpProgressMilestone(
              ordinal: 1,
              roman: 'I',
              tierName: 'Bronze',
              entryXp: 1000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 2,
              roman: 'II',
              tierName: 'Silver',
              entryXp: 3000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 3,
              roman: 'III',
              tierName: 'Gold',
              entryXp: 7000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 4,
              roman: 'IV',
              tierName: 'Crystal',
              entryXp: 15000,
              isCompleted: true,
              isCurrent: true,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 5,
              roman: 'V',
              tierName: 'Diamond',
              entryXp: 30000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
          ],
          sources: const [
            XpSourceMetric(
              name: 'Tasks',
              icon: Icons.check_box_outlined,
              xp: 920,
              percent: 37.6,
            ),
            XpSourceMetric(
              name: 'Projects',
              icon: Icons.folder_outlined,
              xp: 580,
              percent: 23.7,
            ),
            XpSourceMetric(
              name: 'Sessions',
              icon: Icons.access_time_rounded,
              xp: 420,
              percent: 17.1,
            ),
            XpSourceMetric(
              name: 'Goals',
              icon: Icons.track_changes_outlined,
              xp: 320,
              percent: 13.1,
            ),
            XpSourceMetric(
              name: 'Activities',
              icon: Icons.bolt_rounded,
              xp: 150,
              percent: 6.1,
            ),
            XpSourceMetric(
              name: 'Others',
              icon: Icons.more_horiz_rounded,
              xp: 60,
              percent: 2.4,
            ),
          ],
        ),
      );
    } else {
      return Future.value(
        XpProgressData(
          lifeAreaId: null,
          lifeAreaName: 'All Life Areas',
          period: period,
          isAllLifeAreas: true,
          currentXp: 11584,
          targetXp: 14000,
          progressPercent: 82.7,
          remainingXp: 2416,
          totalHistoricalXp: 86420,
          periodXp: 11584,
          periodDelta: const MetricDelta(
            current: 11584,
            previous: 10197,
            changePct: 13.6,
            isPositive: true,
          ),
          levelNumber: 0,
          levelRoman: 'ALL',
          tierName: 'Portfolio',
          tierDescription: 'Aggregate view across all 5 active Life Areas.',
          canPromote: true,
          activeLifeAreasCount: 5,
          topLifeAreaName: 'Professional',
          milestones: const [
            XpProgressMilestone(
              ordinal: 1,
              roman: 'I',
              tierName: 'Bronze',
              entryXp: 1000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 2,
              roman: 'II',
              tierName: 'Silver',
              entryXp: 3000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 3,
              roman: 'III',
              tierName: 'Gold',
              entryXp: 7000,
              isCompleted: true,
              isCurrent: false,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 4,
              roman: 'IV',
              tierName: 'Crystal',
              entryXp: 15000,
              isCompleted: true,
              isCurrent: true,
              isLocked: false,
            ),
            XpProgressMilestone(
              ordinal: 5,
              roman: 'V',
              tierName: 'Diamond',
              entryXp: 30000,
              isCompleted: false,
              isCurrent: false,
              isLocked: true,
            ),
          ],
          sources: const [
            XpSourceMetric(
              name: 'Tasks',
              icon: Icons.check_box_outlined,
              xp: 4320,
              percent: 37.3,
            ),
            XpSourceMetric(
              name: 'Projects',
              icon: Icons.folder_outlined,
              xp: 2840,
              percent: 24.5,
            ),
            XpSourceMetric(
              name: 'Sessions',
              icon: Icons.access_time_rounded,
              xp: 1980,
              percent: 17.1,
            ),
            XpSourceMetric(
              name: 'Goals',
              icon: Icons.track_changes_outlined,
              xp: 1450,
              percent: 12.5,
            ),
            XpSourceMetric(
              name: 'Activities',
              icon: Icons.bolt_rounded,
              xp: 720,
              percent: 6.2,
            ),
            XpSourceMetric(
              name: 'Others',
              icon: Icons.more_horiz_rounded,
              xp: 274,
              percent: 2.4,
            ),
          ],
        ),
      );
    }
  }
}
