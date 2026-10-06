// ignore_for_file: public_member_api_docs
// Wave 1: Goals Main Page — UI Foundation with Liquid Glass Aesthetics.
// Provides 3-row interactive filtering (Life Area, Time, Status) and real data persistence.

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../data/drift/app_database.dart';
import 'dialogs/create_goal_dialog.dart';
import 'goal_detail_screen.dart';
import 'widgets/goal_card.dart';

enum TimeFilter { all, today, week, month, year, custom }

class GoalsScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const GoalsScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String? _selectedLifeAreaId; // null = All
  TimeFilter _selectedTimeFilter = TimeFilter.all;
  DateTimeRange? _customDateRange;
  String _selectedStatus = 'active'; // 'active', 'paused', 'stopped', 'all'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildFiltersSection(context),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildGoalsList(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goals_new_goal_fab',
        onPressed: _openNewGoalDialog,
        backgroundColor: const Color(0xFFEEFF08),
        foregroundColor: const Color(0xFF020302),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        icon: const Icon(Icons.add, size: 18, color: Color(0xFF020302)),
        label: const Text(
          'NEW GOAL',
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8,
            color: Color(0xFF020302),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEFF08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'STRATEGIC INTENT // DIRECTION',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Color(0xFF686D65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'Goals Command',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Color(0xFFF3F1E8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEEFF08).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFEEFF08).withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEFF08),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE TRACKING',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEEFF08),
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050505).withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.8,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row 1: Life Area & Time Dropdowns side-by-side
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildLifeAreaDropdown()),
                const SizedBox(width: 10),
                Expanded(child: _buildTimeFilterDropdown()),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter Row 2: STATUS
          _buildStatusFilterRow(),
        ],
      ),
    );
  }

  Widget _buildLifeAreaDropdown() {
    return StreamBuilder<List<LifeArea>>(
      stream: (widget.database.select(widget.database.lifeAreas)
            ..where((l) =>
                l.ownerId.equals(widget.ownerId) & l.deletedAt.isNull())
            ..orderBy([(l) => drift.OrderingTerm.asc(l.sortOrder)]))
          .watch(),
      builder: (context, snapshot) {
        final lifeAreas = snapshot.data ?? [];

        return KratosDropdown<String?>(
          value: _selectedLifeAreaId,
          hint: 'All Life Areas',
          prefixIcon: Icons.category_outlined,
          isExpanded: true,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          items: [
            const KratosDropdownItem<String?>(
              value: null,
              label: 'All Life Areas',
              leading: Icon(Icons.apps_rounded, size: 15, color: Colors.white54),
            ),
            ...lifeAreas.map((area) {
              Color areaColor = const Color(0xFFC6F135);
              if (area.color != null && area.color!.isNotEmpty) {
                try {
                  areaColor = Color(int.parse(area.color!.replaceFirst('#', '0xFF')));
                } catch (_) {}
              }
              return KratosDropdownItem<String?>(
                value: area.id,
                label: area.name,
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: areaColor, shape: BoxShape.circle),
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedLifeAreaId = val);
          },
        );
      },
    );
  }

  Widget _buildTimeFilterDropdown() {
    return KratosDropdown<TimeFilter>(
      value: _selectedTimeFilter,
      hint: 'All Time',
      prefixIcon: Icons.calendar_month_outlined,
      isExpanded: true,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      items: [
        const KratosDropdownItem(
          value: TimeFilter.all,
          label: 'All Time',
          leading: Icon(Icons.all_inclusive_rounded, size: 15, color: Colors.white54),
        ),
        const KratosDropdownItem(
          value: TimeFilter.today,
          label: 'Today',
          leading: Icon(Icons.today_rounded, size: 15, color: Colors.white54),
        ),
        const KratosDropdownItem(
          value: TimeFilter.week,
          label: 'This Week',
          leading: Icon(Icons.date_range_rounded, size: 15, color: Colors.white54),
        ),
        const KratosDropdownItem(
          value: TimeFilter.month,
          label: 'This Month',
          leading: Icon(Icons.calendar_view_month_rounded, size: 15, color: Colors.white54),
        ),
        const KratosDropdownItem(
          value: TimeFilter.year,
          label: 'This Year',
          leading: Icon(Icons.calendar_today_rounded, size: 15, color: Colors.white54),
        ),
        KratosDropdownItem(
          value: TimeFilter.custom,
          label: _customDateRange != null
              ? '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
              : 'Custom Range...',
          leading: const Icon(Icons.tune_rounded, size: 15, color: Colors.white54),
        ),
      ],
      onChanged: (val) {
        if (val == TimeFilter.custom) {
          _selectCustomRange();
        } else if (val != null) {
          setState(() {
            _selectedTimeFilter = val;
            _customDateRange = null;
          });
        }
      },
    );
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC6F135),
              onPrimary: Color(0xFF020302),
              surface: Color(0xFF141414),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedTimeFilter = TimeFilter.custom;
      });
    }
  }

  Widget _buildStatusFilterRow() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: 'Active',
            badgeColor: const Color(0xFFC6F135),
            isSelected: _selectedStatus == 'active',
            onSelected: () => setState(() => _selectedStatus = 'active'),
          ),
          _buildFilterChip(
            label: 'Paused',
            badgeColor: const Color(0xFFFF9500),
            isSelected: _selectedStatus == 'paused',
            onSelected: () => setState(() => _selectedStatus = 'paused'),
          ),
          _buildFilterChip(
            label: 'Stopped',
            badgeColor: const Color(0xFFFF3B30),
            isSelected: _selectedStatus == 'stopped',
            onSelected: () => setState(() => _selectedStatus = 'stopped'),
          ),
          _buildFilterChip(
            label: 'All Statuses',
            isSelected: _selectedStatus == 'all',
            onSelected: () => setState(() => _selectedStatus = 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? badgeColor,
  }) {
    final activeColor = badgeColor ?? const Color(0xFFEEFF08);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.14)
                : const Color(0xFF101210).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeColor != null) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: isSelected
                      ? const Color(0xFFF3F1E8)
                      : const Color(0xFF979C92),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsList() {
    return StreamBuilder<List<Goal>>(
      stream: widget.database.goalsDao.watchRootGoals(widget.ownerId),
      builder: (context, goalsSnapshot) {
        final isLoading = !goalsSnapshot.hasData;

        return SkeletonReveal(
          loading: isLoading,
          skeleton: const GoalsPageSkeleton(),
          child: !goalsSnapshot.hasData
              ? const SizedBox.shrink()
              : Builder(
                  builder: (context) {
                    final rawGoals = goalsSnapshot.data!;

                    // Apply filters
                    final filteredGoals = rawGoals.where((goal) {
                      // Life Area filter
                      if (_selectedLifeAreaId != null &&
                          goal.lifeAreaId != _selectedLifeAreaId) {
                        return false;
                      }

                      // Status filter
                      if (_selectedStatus != 'all' &&
                          goal.status.toLowerCase() != _selectedStatus.toLowerCase()) {
                        return false;
                      }

                      // Time filter
                      if (!_matchesTimeFilter(goal)) {
                        return false;
                      }

                      return true;
                    }).toList();

                    if (filteredGoals.isEmpty) {
                      return _buildEmptyState();
                    }

                    return StreamBuilder<List<LifeArea>>(
                      stream: widget.database.select(widget.database.lifeAreas).watch(),
                      builder: (context, areasSnapshot) {
                        final areasMap = {
                          for (var a in (areasSnapshot.data ?? [])) a.id: a.name
                        };

                        return StreamBuilder<List<Category>>(
                          stream: widget.database.select(widget.database.categories).watch(),
                          builder: (context, categoriesSnapshot) {
                            final categoriesMap = {
                              for (var c in (categoriesSnapshot.data ?? [])) c.id: c.name
                            };

                            return KratosPageEntrance(
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                                itemCount: filteredGoals.length,
                                itemBuilder: (context, index) {
                                  final goal = filteredGoals[index];
                                  final lifeAreaName = goal.lifeAreaId != null
                                      ? areasMap[goal.lifeAreaId]
                                      : null;
                                  final categoryName = goal.categoryId != null
                                      ? categoriesMap[goal.categoryId]
                                      : null;

                                  return GoalCard(
                                    goal: goal,
                                    lifeAreaName: lifeAreaName,
                                    categoryName: categoryName,
                                    onTap: () => _openGoalDetail(goal),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  bool _matchesTimeFilter(Goal goal) {
    if (_selectedTimeFilter == TimeFilter.all) return true;
    final now = DateTime.now();
    final targetDate = goal.dueDate ?? goal.createdAt;

    switch (_selectedTimeFilter) {
      case TimeFilter.today:
        return targetDate.year == now.year &&
            targetDate.month == now.month &&
            targetDate.day == now.day;
      case TimeFilter.week:
        final diff = targetDate.difference(now).inDays.abs();
        return diff <= 7;
      case TimeFilter.month:
        return targetDate.year == now.year && targetDate.month == now.month;
      case TimeFilter.year:
        return targetDate.year == now.year;
      case TimeFilter.custom:
        if (_customDateRange == null) return true;
        return targetDate.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
            targetDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      case TimeFilter.all:
        return true;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF141714),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEEFF08).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFEEFF08),
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ZERO INTENT DETECTED',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF686D65),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No Matching Goals Found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Color(0xFFF3F1E8),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adjust filters or create a new goal node to begin tracking your strategic progression.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF979C92),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _openNewGoalDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFF08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '+ CREATE FIRST GOAL',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF020302),
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

  void _openNewGoalDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        defaultLifeAreaId: _selectedLifeAreaId,
        onGoalCreated: (newGoal) {
          Navigator.of(context).pop();
          _openGoalDetail(newGoal);
        },
      ),
    );
  }

  void _openGoalDetail(Goal goal) {
    Navigator.of(context).push(
      KratosPageRoute(
        page: GoalDetailScreen(
          database: widget.database,
          ownerId: widget.ownerId,
          goalId: goal.id,
        ),
      ),
    );
  }
}
