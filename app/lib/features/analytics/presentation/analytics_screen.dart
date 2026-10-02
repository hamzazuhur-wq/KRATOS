import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/drift/app_database.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

enum _Metric { xp, activity, completion }

class AnalyticsScreen extends StatefulWidget {
  final String ownerId;
  final AppDatabase? database;
  final AnalyticsRepository? repository;

  const AnalyticsScreen({
    super.key,
    required this.ownerId,
    this.database,
    this.repository,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final AnalyticsRepository _repo;
  late Future<List<({String id, String name})>> _areas;
  late Future<AnalyticsSnapshot> _data;
  AnalyticsPeriod _period = AnalyticsPeriod.thirtyDays;
  String? _area;
  _Metric _metric = _Metric.xp;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AnalyticsRepository(widget.database);
    _areas = _repo.listLifeAreas(widget.ownerId);
    _load();
  }

  void _load() {
    _data = _repo.load(
      ownerId: widget.ownerId,
      range: AnalyticsDateRange.forPeriod(_period),
      lifeAreaId: _area,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Analytics'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_outlined)),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const KratosEnvironment(),
        FutureBuilder<List<({String id, String name})>>(
          future: _areas,
          builder: (context, areas) {
            if (areas.hasError) {
              return _state('Unable to load Analytics. Try again.');
            }
            if (!areas.hasData) {
              return const KratosShimmer(child: AnalyticsPageSkeleton());
            }
            return FutureBuilder<AnalyticsSnapshot>(
              future: _data,
              builder: (context, result) {
                if (result.hasError) {
                  return _state('Analytics is temporarily unavailable.');
                }
                if (!result.hasData) {
                  return const KratosShimmer(child: AnalyticsPageSkeleton());
                }
                final d = result.data!;
                return RefreshIndicator(
                  color: KratosTheme.acidLime,
                  onRefresh: () async => _load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _filters(areas.data!),
                      _section(
                        'CATEGORIES',
                        _chips([
                          'All',
                          'Goals',
                          'Projects',
                          'Tasks',
                          'Habits & Focus',
                        ]),
                      ),
                      _section('CURRENT STATE', _stateCards(d)),
                      _section('GROWTH & MOMENTUM', _growth(d)),
                      _section(
                        'LIFE AREA PERFORMANCE',
                        _chart(
                          d.lifeAreas.map((a) => a.progress).toList(),
                          KratosTheme.cyan,
                          d.lifeAreas
                              .map(
                                (a) =>
                                    '${a.name} · ${a.trendPct.toStringAsFixed(0)}% trend',
                              )
                              .toList(),
                        ),
                      ),
                      _section(
                        'ACTIVITY OVERVIEW',
                        _chart(
                          [
                            d.createdTasks > 0 ? (d.completedTasks / d.createdTasks).clamp(0.0, 1.0) : 0.0,
                            d.createdGoals > 0 ? (d.completedGoals / d.createdGoals).clamp(0.0, 1.0) : 0.0,
                            d.createdProjects > 0 ? (d.completedProjects / d.createdProjects).clamp(0.0, 1.0) : 0.0,
                            d.createdDecisions > 0 ? (d.completedDecisions / d.createdDecisions).clamp(0.0, 1.0) : 0.0,
                          ],
                          KratosTheme.acidLime,
                          [
                            'Tasks · ${d.createdTasks} / ${d.completedTasks}',
                            'Goals · ${d.createdGoals} / ${d.completedGoals}',
                            'Projects · ${d.createdProjects} / ${d.completedProjects}',
                            'Decisions · ${d.createdDecisions} / ${d.completedDecisions}',
                          ],
                        ),
                      ),
                      _section('ACTIVITY HEATMAP', _heatmap(d)),
                      _section(
                        'WHERE YOUR XP COMES FROM',
                        _chart(
                          d.xpBySource.values
                              .map((v) => d.totalXp > 0 ? (v / d.totalXp).clamp(0.0, 1.0) : 0.0)
                              .toList(),
                          KratosTheme.flameOrange,
                          d.xpBySource.entries
                              .map(
                                (e) =>
                                    '${e.key} · ${d.totalXp > 0 ? (e.value / d.totalXp * 100).round() : 0}%',
                              )
                              .toList(),
                        ),
                      ),
                      _section(
                        'XP BY LIFE AREA',
                        _rows(
                          d.lifeAreas.isEmpty
                              ? ['No life area activity recorded']
                              : d.lifeAreas
                                  .map(
                                    (a) =>
                                        '${a.name} · ${a.xp} XP · ${a.trendPct.toStringAsFixed(0)}% trend',
                                  )
                                  .toList(),
                        ),
                      ),
                      _section(
                        'GOAL HEALTH',
                        _rows(
                          d.goalHealth.isEmpty
                              ? ['No goals active in this period']
                              : d.goalHealth
                                  .map(
                                    (g) =>
                                        '${g.title} · ${(g.progress * 100).round()}% · ${g.status} · ${g.momentum}',
                                  )
                                  .toList(),
                        ),
                      ),
                      _section(
                        'PROJECT PERFORMANCE',
                        _rows(
                          d.projectPerformance.isEmpty
                              ? ['No projects active in this period']
                              : d.projectPerformance
                                  .map(
                                    (p) =>
                                        '${p.title} · ${(p.progress * 100).round()}% · ${p.status} · ${p.xpEarned} XP',
                                  )
                                  .toList(),
                        ),
                      ),
                      _section(
                        'TASK PERFORMANCE',
                        _chart(
                          d.dailyGrowthSeries
                              .take(14)
                              .map((p) => p.completionRate)
                              .toList(),
                          KratosTheme.acidLime,
                          [
                            'Created · ${d.createdTasks}',
                            'Completed · ${d.completedTasks}',
                            'Completion Rate · ${d.completionRateDelta.current.round()}%',
                            'Active Tasks · ${d.activeTasks}',
                          ],
                        ),
                      ),
                      _section(
                        'DECISION ACTIVITY',
                        _rows([
                          'Decisions created · ${d.createdDecisions}',
                          'Decisions resolved · ${d.completedDecisions}',
                          'Activity over time · ${d.createdDecisions + d.completedDecisions} events',
                          'XP contribution · ${d.xpBySource['Decisions'] ?? 0} XP',
                        ]),
                      ),
                      _section(
                        'ACTIVITY PATTERNS',
                        _rows([
                          'By day · ${d.activityByDayOfWeek.entries.map((e) => '${_dayName(e.key)}: ${e.value}').join(' · ')}',
                          'Morning · ${d.activityByTimeOfDay['Morning'] ?? 0}',
                          'Afternoon · ${d.activityByTimeOfDay['Afternoon'] ?? 0}',
                          'Evening · ${d.activityByTimeOfDay['Evening'] ?? 0}',
                          'Peak activity · ${_findPeakActivity(d)}',
                        ]),
                      ),
                      _section(
                        'ACTIVITY VS COMPLETION',
                        _chart(
                          d.dailyGrowthSeries
                              .take(12)
                              .map((p) => (p.totalActivity / 16).clamp(0.0, 1.0))
                              .toList(),
                          KratosTheme.cyan,
                          [
                            'Activity · ${d.activitiesStarted}',
                            'Completion · ${d.completionRateDelta.current.round()}%',
                            'XP · ${NumberFormat('#,###').format(d.totalXp)}',
                            'Comparison only — no causality inferred',
                          ],
                        ),
                      ),
                      _section(
                        'CONSISTENCY',
                        _rows([
                          'Current Streak · ${d.currentStreak}d',
                          'Longest Streak · ${d.longestStreak}d',
                          'Active Days · ${d.activeDaysCount}',
                          'Consistency · ${d.consistencyDelta.current.round()}%',
                          'Average Active Days / Week · ${(d.activeDaysCount / (d.range.dayCount > 0 ? d.range.dayCount : 1) * 7).toStringAsFixed(1)}',
                        ]),
                      ),
                      _section(
                        'MILESTONES',
                        _timeline(
                          d.milestones.isEmpty
                              ? ['No milestones reached in this period']
                              : d.milestones
                                  .map((m) => '${m.title} · ${m.description}')
                                  .toList(),
                        ),
                      ),
                      _section(
                        'RECENT ACTIVITY',
                        _timeline(
                          d.recentActivity.isEmpty
                              ? ['No recent activity in this period']
                              : d.recentActivity
                                  .map((e) => '${e.title} · +${e.points} XP')
                                  .toList(),
                        ),
                      ),
                      _section(
                        'INSIGHTS',
                        _rows(
                          d.insights.isEmpty
                              ? ['Keep logging activity to unlock personalized insights']
                              : d.insights
                                  .map((i) => '${i.title} — ${i.description}')
                                  .toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );

  Widget _filters(List<({String id, String name})> areas) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            KratosGlassCard(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (final item in [
                    ('7D', AnalyticsPeriod.sevenDays),
                    ('30D', AnalyticsPeriod.thirtyDays),
                    ('90D', AnalyticsPeriod.ninetyDays),
                    ('1Y', AnalyticsPeriod.oneYear),
                  ])
                    _range(item.$1, item.$2),
                ],
              ),
            ),
            const SizedBox(width: 12),
            KratosDropdown<String?>(
              value: _area,
              hint: 'All Areas',
              prefixIcon: Icons.public,
              items: [
                const KratosDropdownItem(value: null, label: 'All Areas'),
                ...areas.map(
                  (a) => KratosDropdownItem(value: a.id, label: a.name),
                ),
              ],
              onChanged: (v) {
                setState(() => _area = v);
                _load();
              },
            ),
          ],
        ),
      );
  Widget _range(String label, AnalyticsPeriod value) => GestureDetector(
    onTap: () {
      setState(() => _period = value);
      _load();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _period == value ? KratosTheme.acidLime : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _period == value ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
  Widget _chips(List<String> values) => Wrap(
    spacing: 8,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(value),
          selected: value == 'All',
          onSelected: (_) {},
        ),
    ],
  );
  Widget _stateCards(AnalyticsSnapshot d) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth > 720 ? 4 : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          _card(
            'Total XP',
            '${NumberFormat('#,###').format(d.totalXp)} XP',
            '${d.xpDelta.isPositive ? '↑' : '↓'} ${d.xpDelta.changePct.abs().toStringAsFixed(1)}% · vs previous period',
            KratosTheme.acidLime,
          ),
          _card(
            'XP Velocity',
            '+${d.xpVelocityDelta.current.round()} / day',
            '${d.xpVelocityDelta.isPositive ? '↑' : '↓'} ${d.xpVelocityDelta.changePct.abs().toStringAsFixed(1)}%',
            KratosTheme.cyan,
          ),
          _card(
            'Completion Rate',
            '${d.completionRateDelta.current.round()}%',
            '${d.completionRateDelta.isPositive ? '↑' : '↓'} ${d.completionRateDelta.changePct.abs().toStringAsFixed(1)}%',
            const Color(0xFF38EF7D),
          ),
          _card(
            'Consistency',
            '${d.consistencyDelta.current.round()}%',
            '${d.consistencyDelta.isPositive ? '↑' : '↓'} ${d.consistencyDelta.changePct.abs().toStringAsFixed(1)}%',
            KratosTheme.flameOrange,
          ),
        ],
      );
    },
  );
  Widget _card(String title, String value, String delta, Color color) =>
      Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            accentColor: color,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  delta,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      );
  Widget _growth(AnalyticsSnapshot d) => KratosGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _tab('XP', _Metric.xp),
            _tab('Activity', _Metric.activity),
            _tab('Completion', _Metric.completion),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _metric == _Metric.xp
              ? '+${NumberFormat('#,###').format(d.totalXp)} XP'
              : _metric == _Metric.activity
              ? '${d.activitiesStarted} activities'
              : '${d.completionRateDelta.current.round()}%',
          style: const TextStyle(
            color: KratosTheme.acidLime,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _LinePainter(d.dailyGrowthSeries, _metric),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM d').format(d.range.start),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const Text(
              'Previous period comparison',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            Text(
              DateFormat('MMM d')
                  .format(d.range.end.subtract(const Duration(days: 1))),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _tab(String label, _Metric value) => ChoiceChip(
    label: Text(label),
    selected: _metric == value,
    onSelected: (_) => setState(() => _metric = value),
  );
  Widget _chart(List<double> values, Color color, List<String> labels) =>
      KratosGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 125,
              child: CustomPaint(
                painter: _BarsPainter(values, color),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            _rows(labels),
          ],
        ),
      );
  Widget _heatmap(AnalyticsSnapshot d) => KratosGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final p in d.dailyGrowthSeries)
              Tooltip(
                message: '${p.xp} XP · ${p.totalActivity} activities',
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: KratosTheme.acidLime.withValues(
                      alpha: .18 + (p.xp / 650).clamp(.0, .65),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _rows([
          'Active Days · ${d.activeDaysCount}',
          'Best Streak · ${d.longestStreak}d',
          'Current Streak · ${d.currentStreak}d',
          'Average Daily XP · ${d.xpVelocityDelta.current.round()}',
        ]),
      ],
    ),
  );
  Widget _rows(List<String> values) => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return KratosGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      color: KratosTheme.acidLime,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _timeline(List<String> values) => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return KratosGlassCard(
        child: Column(
          children: [
            for (final value in values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.bolt_outlined,
                  color: KratosTheme.acidLime,
                ),
                title: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'Recorded event',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  static String _dayName(int day) => switch (day) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
    _ => '',
  };

  static String _findPeakActivity(AnalyticsSnapshot d) {
    if (d.activityByDayOfWeek.isEmpty && d.activityByTimeOfDay.isEmpty) {
      return 'No activity recorded';
    }
    var peakDay = 1;
    var maxDayVal = -1;
    for (final entry in d.activityByDayOfWeek.entries) {
      if (entry.value > maxDayVal) {
        maxDayVal = entry.value;
        peakDay = entry.key;
      }
    }
    var peakTime = 'Morning';
    var maxTimeVal = -1;
    for (final entry in d.activityByTimeOfDay.entries) {
      if (entry.value > maxTimeVal) {
        maxTimeVal = entry.value;
        peakTime = entry.key;
      }
    }
    if (maxDayVal <= 0 && maxTimeVal <= 0) return 'No activity recorded';
    return '${_dayName(peakDay)} $peakTime';
  }
  Widget _section(String title, Widget child) => Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
    },
  );
  Widget _state(String message) => Center(
    child: KratosGlassCard(
      child: Text(message, style: const TextStyle(color: Colors.white70)),
    ),
  );
}

class _LinePainter extends CustomPainter {
  final List<DailyAnalyticsPoint> points;
  final _Metric metric;
  const _LinePainter(this.points, this.metric);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points
        .map(
          (p) => metric == _Metric.xp
              ? p.xp.toDouble()
              : metric == _Metric.activity
              ? p.totalActivity.toDouble()
              : p.completionRate * 100,
        )
        .toList();
    final max = values.reduce(math.max).toDouble();
    final min = values.reduce(math.min);
    final span = math.max(1.0, max - min);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : i / (values.length - 1) * size.width;
      final y =
          size.height - ((values[i] - min) / span * (size.height - 14)) - 7;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = KratosTheme.acidLime.withValues(alpha: .08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = KratosTheme.acidLime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        Paint()..color = Colors.white.withValues(alpha: .08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points || old.metric != metric;
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _BarsPainter(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = math.max(1.0, values.reduce(math.max));
    final gap = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final height = values[i] / max * (size.height - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * gap + gap * .18,
            size.height - height,
            gap * .64,
            height,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = color.withValues(alpha: .35 + i / values.length * .5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.values != values;
}
