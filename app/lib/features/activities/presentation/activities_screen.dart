// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../categories/data/categories_dao.dart';
import '../../sessions/domain/global_active_session_controller.dart';
import '../../sessions/presentation/timer_status_badge.dart';
import '../data/activity_dashboard_repository.dart';
import '../domain/activity_models.dart';
import 'activity_detail_screen.dart';
import 'create_activity_dialog.dart';

class ActivitiesScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const ActivitiesScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late final ActivityDashboardRepository _repository;
  late Stream<List<ActivityDashboardItem>> _activitiesStream;

  String? _selectedLifeAreaId;
  String? _selectedCategoryId;
  ActivityDashboardTime _selectedTime = ActivityDashboardTime.today;
  DateTimeRange? _customRange;

  List<LifeArea> _lifeAreas = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _repository = ActivityDashboardRepository(widget.database);
    _updateStream();
    _loadFilters();
    GlobalActiveSessionController().bindDatabase(
      widget.database,
      widget.ownerId,
    );
  }

  void _updateStream() {
    _activitiesStream = _repository.watchActivitiesDashboard(
      ownerId: widget.ownerId,
      lifeAreaId: _selectedLifeAreaId,
      categoryId: _selectedCategoryId,
      time: _selectedTime,
      customRange: _customRange,
    );
  }

  Future<void> _loadFilters() async {
    try {
      final areas =
          await (widget.database.select(widget.database.lifeAreas)
                ..where(
                  (a) =>
                      a.ownerId.equals(widget.ownerId) &
                      a.deletedAt.isNull() &
                      a.archivedAt.isNull(),
                )
                ..orderBy([
                  (a) => OrderingTerm.asc(a.sortOrder),
                  (a) => OrderingTerm.asc(a.name),
                ]))
              .get();

      final categoriesDao = CategoriesDao(widget.database);
      final cats = await categoriesDao.categoriesByType(
        widget.ownerId,
        'activity',
      );

      if (mounted) {
        setState(() {
          _lifeAreas = areas;
          _categories = cats;
        });
      }
    } catch (_) {}
  }

  Future<void> _openNewActivity() async {
    final activityId = await CreateActivityDialog.show(
      context,
      database: widget.database,
      ownerId: widget.ownerId,
      initialLifeAreaId: _selectedLifeAreaId,
    );

    if (activityId != null && mounted) {
      Navigator.of(context).push(
        KratosMaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            database: widget.database,
            ownerId: widget.ownerId,
            activityId: activityId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACTIVITIES',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                fontSize: 16,
              ),
            ),
            Text(
              'Repeatable practices, habits, and tracked routines',
              style: TextStyle(
                color: isDark ? Colors.white38 : KratosTheme.lightTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openNewActivity,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF0D0D0D)),
              label: const Text(
                'New Activity',
                style: TextStyle(
                  color: Color(0xFF0D0D0D),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC6F135),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          Column(
            children: [
              // Filter Bar
              _buildFilterBar(),

              // Activities List
              Expanded(
                child: StreamBuilder<List<ActivityDashboardItem>>(
                  stream: _activitiesStream,
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData;
                    final items = snapshot.data ?? [];

                    return SkeletonReveal(
                      loading: isLoading,
                      skeleton: const ActivitiesPageSkeleton(),
                      child: !snapshot.hasData
                          ? const SizedBox.shrink()
                          : (items.isEmpty
                                ? _buildEmptyState()
                                : KratosPageEntrance(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: items.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        return _ActivityCard(
                                          item: item,
                                          database: widget.database,
                                          ownerId: widget.ownerId,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              KratosPageRoute(
                                                page: ActivityDetailScreen(
                                                  database: widget.database,
                                                  ownerId: widget.ownerId,
                                                  activityId: item.id,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  )),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Life Area filter dropdown
            KratosDropdown<String?>(
              value: _selectedLifeAreaId,
              hint: 'All Life Areas',
              prefixIcon: Icons.dashboard_customize_outlined,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: [
                const KratosDropdownItem(value: null, label: 'All Life Areas'),
                ..._lifeAreas.map(
                  (la) => KratosDropdownItem(value: la.id, label: la.name),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedLifeAreaId = val;
                  _updateStream();
                });
              },
            ),
            const SizedBox(width: 8),

            // Category filter dropdown
            KratosDropdown<String?>(
              value: _selectedCategoryId,
              hint: 'All Categories',
              prefixIcon: Icons.category_outlined,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: [
                const KratosDropdownItem(value: null, label: 'All Categories'),
                ..._categories.map(
                  (c) => KratosDropdownItem(value: c.id, label: c.name),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                  _updateStream();
                });
              },
            ),
            const SizedBox(width: 8),

            // Time filter chips
            _buildTimeChip(ActivityDashboardTime.today, 'Today'),
            const SizedBox(width: 6),
            _buildTimeChip(ActivityDashboardTime.week, 'This Week'),
            const SizedBox(width: 6),
            _buildTimeChip(ActivityDashboardTime.month, 'This Month'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(ActivityDashboardTime time, String label) {
    final isSelected = _selectedTime == time;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selectedColor: const Color(0xFFC6F135),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFC6F135)
            : Colors.white.withValues(alpha: 0.1),
      ),
      onSelected: (_) {
        setState(() {
          _selectedTime = time;
          _updateStream();
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFC6F135).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_activity_outlined,
                color: Color(0xFFC6F135),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Activities Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create repeatable activities like Reading, Gym, Studying, or Coding Practice to track focus sessions and earn XP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openNewActivity,
              icon: const Icon(Icons.add, color: Colors.black, size: 16),
              label: const Text(
                'Create First Activity',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC6F135),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityDashboardItem item;
  final AppDatabase database;
  final String ownerId;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.item,
    required this.database,
    required this.ownerId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = GlobalActiveSessionController();

    return StreamBuilder<ActiveSessionState?>(
      stream: controller.stream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final activeState = snapshot.data;
        final isActive =
            activeState != null &&
            activeState.entityType == 'activity' &&
            activeState.entityId == item.id;
        final isPaused = isActive && activeState.isPaused;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return KratosGlassCard(
          variant: isActive
              ? KratosSurfaceVariant.active
              : KratosSurfaceVariant.interactive,
          interactive: true,
          accentColor: isActive
              ? (isPaused ? Colors.amber : const Color(0xFFC6F135))
              : null,
          borderRadius: BorderRadius.circular(16),
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Title + Action
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC6F135)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFC6F135)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_activity,
                            color: Color(0xFFC6F135),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (item.lifeAreaName != null)
                                    _badge(
                                      item.lifeAreaName!,
                                      const Color(0xFFC6F135),
                                    ),
                                  if (item.categoryName != null)
                                    _badge(
                                      item.categoryName!,
                                      Colors.tealAccent,
                                    ),
                                  if (item.targetDurationMinutes != null &&
                                      item.targetDurationMinutes! > 0)
                                    _badge(
                                      'Target ${item.formattedTargetDuration}',
                                      Colors.amberAccent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Start / Active / Quick Log Buttons
                        if (isActive) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TimerStatusBadge(isPaused: isPaused),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isPaused
                                              ? Colors.amber
                                              : const Color(0xFFC6F135))
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPaused
                                        ? Colors.amber
                                        : const Color(0xFFC6F135),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPaused
                                            ? Colors.amber
                                            : const Color(0xFFC6F135),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      activeState.formattedElapsed,
                                      style: TextStyle(
                                        color: isPaused
                                            ? Colors.amber
                                            : const Color(0xFFC6F135),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  isPaused ? Icons.play_arrow : Icons.pause,
                                  color: isPaused
                                      ? const Color(0xFFC6F135)
                                      : Colors.amber,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (isPaused) {
                                    controller.resumeSession();
                                  } else {
                                    controller.pauseSession();
                                  }
                                },
                                tooltip: isPaused ? 'Resume' : 'Pause',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFC6F135),
                                  size: 24,
                                ),
                                onPressed: () async {
                                  final res = await controller.completeSession(
                                    database: database,
                                    ownerId: ownerId,
                                  );
                                  if (context.mounted && res != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(
                                          0xFF141F14,
                                        ),
                                        content: Text(
                                          'Session completed! +${res['xpEarned']} XP awarded to ${item.lifeAreaName ?? 'Life Area'}.',
                                          style: const TextStyle(
                                            color: Color(0xFFC6F135),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Complete session (+XP)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFFC6F135),
                                  size: 24,
                                ),
                                onPressed: () async {
                                  final repo = ActivityDashboardRepository(
                                    database,
                                  );
                                  final earned = await repo.quickLogSession(
                                    activityId: item.id,
                                    ownerId: ownerId,
                                    durationMinutes:
                                        item.targetDurationMinutes ?? 30,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(
                                          0xFF141F14,
                                        ),
                                        content: Text(
                                          'Logged "${item.name}"! +$earned XP awarded to ${item.lifeAreaName ?? 'Life Area'}.',
                                          style: const TextStyle(
                                            color: Color(0xFFC6F135),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Quick Log Session (+XP)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Color(0xFFC6F135),
                                  size: 28,
                                ),
                                onPressed: () {
                                  controller.startSession(
                                    entityType: 'activity',
                                    entityId: item.id,
                                    title: item.name,
                                    lifeAreaId: item.lifeAreaId,
                                    lifeAreaName: item.lifeAreaName,
                                    categoryName: item.categoryName,
                                    targetDurationMinutes:
                                        item.targetDurationMinutes ?? 0,
                                  );
                                },
                                tooltip: 'Start timer',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Stats summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.periodSessionCount} Sessions • ${item.formattedPeriodDuration}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '+${item.periodXpEarned} XP',
                            style: const TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
