// Wave 2 & Master Prompt: Category System Architecture & Accordion Settings UX.
// Supports 4 independent, semantic category groups:
// 1. Goal Categories
// 2. Task Categories
// 3. Activity Categories
// 4. Life Area Categories
//
// Features expandable accordion groups, SCD Type-2 rule versioning,
// real Drift SQLite persistence, sync outbox integration, and robust 3-state handling.

import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../activities/domain/activity_xp_calculator.dart';
import '../../xp/domain/base_xp_config.dart';

class CategoriesScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String initialCategoryType; // 'goal', 'task', 'activity', 'life_area'

  const CategoriesScreen({
    super.key,
    required this.database,
    required this.ownerId,
    this.initialCategoryType = 'goal',
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoryGroupMeta {
  final String key;
  final String title;
  final String singularTitle;
  final IconData icon;
  final String description;

  const _CategoryGroupMeta({
    required this.key,
    required this.title,
    required this.singularTitle,
    required this.icon,
    required this.description,
  });
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _showArchived = false;
  late final Set<String> _expandedKeys;

  static const List<_CategoryGroupMeta> _groups = [
    _CategoryGroupMeta(
      key: 'goal',
      title: 'Goal Categories',
      singularTitle: 'Goal Category',
      icon: Icons.track_changes,
      description:
          'Used by Main Goals & Sub-goals to classify long-term objectives.',
    ),
    _CategoryGroupMeta(
      key: 'task',
      title: 'Task Categories',
      singularTitle: 'Task Category',
      icon: Icons.check_circle_outline,
      description:
          'Used by everyday and goal-linked tasks to define work focus.',
    ),
    _CategoryGroupMeta(
      key: 'activity',
      title: 'Activity Categories',
      singularTitle: 'Activity Category',
      icon: Icons.repeat,
      description: 'Used by recurring habits, routines, and practice drills.',
    ),
    _CategoryGroupMeta(
      key: 'life_area',
      title: 'Life Area Categories',
      singularTitle: 'Life Area Category',
      icon: Icons.dashboard_customize_outlined,
      description:
          'Used to classify core life domains (Professional, Health, etc.).',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _expandedKeys = {widget.initialCategoryType};
    widget.database.categoriesDao.ensureSeeded(widget.ownerId);
  }

  void _toggleGroup(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  void _openCategoryEditor({Category? category, required String type}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryEditorSheet(
        database: widget.database,
        ownerId: widget.ownerId,
        category: category,
        categoryType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CATEGORIES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showArchived ? Icons.visibility : Icons.visibility_off_outlined,
              color: _showArchived ? const Color(0xFFC6F135) : Colors.white38,
              size: 20,
            ),
            tooltip: _showArchived ? 'Hide Archived' : 'Show Archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ActiveGlassCard(
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFC6F135),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Manage the categories used throughout KRATOS.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.initialCategoryType == '__xp_rules__')
            const _EntityXpRulesSection(),
          ..._groups.map((group) {
            final isExpanded = _expandedKeys.contains(group.key);
            return _AccordionGroupCard(
              database: widget.database,
              ownerId: widget.ownerId,
              group: group,
              isExpanded: isExpanded,
              showArchived: _showArchived,
              onToggle: () => _toggleGroup(group.key),
              onAddCategory: () => _openCategoryEditor(type: group.key),
              onEditCategory: (cat) =>
                  _openCategoryEditor(category: cat, type: group.key),
            );
          }),
        ],
      ),
        ],
      ),
    );
  }
}

class _EntityXpRulesSection extends StatefulWidget {
  const _EntityXpRulesSection();

  @override
  State<_EntityXpRulesSection> createState() => _EntityXpRulesSectionState();
}

class _EntityXpRulesSectionState extends State<_EntityXpRulesSection> {
  static const _durations = [0, 15, 30, 60, 120, 240, 360, 480, 600, 720];
  final Map<BaseXpSource, int> _difficulty = {
    for (final source in BaseXpSource.values) source: 5,
  };
  int _activityMinutes = 120;

  int _xp(BaseXpSource source, int difficulty) => switch (source) {
    BaseXpSource.activity => ActivityXpCalculator.ceilingXp(difficulty),
    BaseXpSource.skill => BaseXpConfig.forSkill(difficulty),
    BaseXpSource.task => BaseXpConfig.forTask(difficulty),
    BaseXpSource.subGoal => BaseXpConfig.forSubGoal(difficulty),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ENTITY XP RULES · PREVIEW',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final source in const [
            BaseXpSource.task,
            BaseXpSource.activity,
            BaseXpSource.subGoal,
            BaseXpSource.skill,
          ])
            _ruleCard(source),
        ],
      ),
    );
  }

  Widget _ruleCard(BaseXpSource source) {
    final difficulty = _difficulty[source]!;
    final maximum = BaseXpConfig.maxPointsFor(source);
    final isActivity = source == BaseXpSource.activity;
    final factor = isActivity
        ? ActivityXpCalculator.durationFactor(_activityMinutes)
        : 1.0;
    final previewXp = isActivity
        ? ActivityXpCalculator.calculateActivityXp(
            difficulty,
            Duration(minutes: _activityMinutes),
          )
        : _xp(source, difficulty);
    final label = switch (source) {
      BaseXpSource.activity => 'ACTIVITY',
      BaseXpSource.skill => 'SKILL',
      BaseXpSource.task => 'TASK',
      BaseXpSource.subGoal => 'SUB-GOAL',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                'MAX $maximum XP',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'DIFFICULTY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KratosDropdown<int>(
                  value: difficulty,
                  hint: 'Difficulty',
                  isExpanded: true,
                  items: [
                    for (var value = 1; value <= 10; value++)
                      KratosDropdownItem(value: value, label: '$value / 10'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _difficulty[source] = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '$previewXp XP',
                  key: ValueKey('$previewXp-$factor'),
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (isActivity) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SESSION DURATION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 138,
                  child: KratosDropdown<int>(
                    value: _activityMinutes,
                    hint: 'Duration',
                    isExpanded: true,
                    items: [
                      for (final minutes in _durations)
                        KratosDropdownItem(
                          value: minutes,
                          label: minutes == 0 ? '0 min' : '$minutes min',
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _activityMinutes = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'CEILING ${_xp(source, difficulty)} XP  ·  DURATION ${(factor * 100).round()}%  ·  MAX 720 MIN',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final minutes in _durations)
                  Text(
                    '$minutes′ ${(ActivityXpCalculator.durationFactor(minutes) * 100).round()}%',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accordion Group Card
// ---------------------------------------------------------------------------

class _AccordionGroupCard extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final _CategoryGroupMeta group;
  final bool isExpanded;
  final bool showArchived;
  final VoidCallback onToggle;
  final VoidCallback onAddCategory;
  final ValueChanged<Category> onEditCategory;

  const _AccordionGroupCard({
    required this.database,
    required this.ownerId,
    required this.group,
    required this.isExpanded,
    required this.showArchived,
    required this.onToggle,
    required this.onAddCategory,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    final stream = showArchived
        ? database.categoriesDao.watchAllCategoriesByType(ownerId, group.key)
        : database.categoriesDao.watchCategoriesByType(ownerId, group.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFFC6F135).withValues(alpha: 0.35)
              : Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? const Color(0xFFC6F135).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      group.icon,
                      color: isExpanded
                          ? const Color(0xFFC6F135)
                          : Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: TextStyle(
                            color: isExpanded
                                ? const Color(0xFFC6F135)
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.description,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<Category>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Body
          if (isExpanded)
            StreamBuilder<List<Category>>(
              stream: stream,
              builder: (context, snapshot) {
                // 1. Error state
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFFF3B30),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Could not load ${group.title}.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 2. Loading state
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFC6F135),
                        ),
                      ),
                    ),
                  );
                }

                final categories = snapshot.data!;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 10),

                      // 3. Empty state
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Column(
                              children: [
                                const Text(
                                  'No categories defined yet',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _AddCategoryButton(
                                  label: '+ Add ${group.singularTitle}',
                                  onTap: onAddCategory,
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // 4. Data list
                        ...categories.map(
                          (cat) => _CategoryItemRow(
                            database: database,
                            ownerId: ownerId,
                            category: cat,
                            onEdit: () => onEditCategory(cat),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AddCategoryButton(
                          label: '+ Add ${group.singularTitle}',
                          onTap: onAddCategory,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Category Button
// ---------------------------------------------------------------------------

class _AddCategoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCategoryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFC6F135).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Color(0xFFC6F135), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC6F135),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Item Row
// ---------------------------------------------------------------------------

class _CategoryItemRow extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final Category category;
  final VoidCallback onEdit;

  const _CategoryItemRow({
    required this.database,
    required this.ownerId,
    required this.category,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isArchived = category.archivedAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isArchived
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isArchived ? Colors.white10 : Colors.white12,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Icon avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              category.icon != null && category.icon!.isNotEmpty
                  ? category.icon!
                  : '🏷️',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),

          // Name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          color: isArchived ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: isArchived
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isArchived) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ARCHIVED',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (category.description != null &&
                    category.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      category.description!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Base XP badge
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${category.baseXp} XP',
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

          // Popup Menu
          KratosPopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (context) => [
              const KratosPopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isArchived)
                const KratosPopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 16,
                        color: Color(0xFFFF9500),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Archive',
                        style: TextStyle(
                          color: Color(0xFFFF9500),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const KratosPopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(
                        Icons.unarchive_outlined,
                        size: 16,
                        color: Color(0xFFC6F135),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Restore',
                        style: TextStyle(
                          color: Color(0xFFC6F135),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const KratosPopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFFF3B30),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final hlc = Hlc.now(Id.uuidV7()).toString();

    if (action == 'edit') {
      onEdit();
    } else if (action == 'archive') {
      await database.categoriesDao.archiveCategory(category.id, hlc);
      await _enqueueSync(
        op: 'update',
        payload: {'archived_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archived "${category.name}"'),
            backgroundColor: const Color(0xFF141414),
          ),
        );
      }
    } else if (action == 'restore') {
      await database.categoriesDao.restoreCategory(category.id, hlc);
      await _enqueueSync(op: 'update', payload: {'archived_at': null});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored "${category.name}"'),
            backgroundColor: const Color(0xFF141414),
          ),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Delete Category?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to permanently delete "${category.name}"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await database.categoriesDao.deleteCategory(category.id);
        await _enqueueSync(op: 'delete', payload: {'id': category.id});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${category.name}"'),
              backgroundColor: const Color(0xFF141414),
            ),
          );
        }
      }
    }
  }

  Future<void> _enqueueSync({
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    await database
        .into(database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: op,
            entity: 'categories',
            entityId: category.id,
            payloadJson: jsonEncode(payload),
            hlc: Hlc.now(Id.uuidV7()).toString(),
            deviceId: 'local_device',
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Category Creation / Edit Bottom Sheet
// ---------------------------------------------------------------------------

class _CategoryEditorSheet extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Category? category;
  final String categoryType; // 'goal', 'task', 'activity', 'life_area'

  const _CategoryEditorSheet({
    required this.database,
    required this.ownerId,
    this.category,
    required this.categoryType,
  });

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _iconController;
  late final TextEditingController _baseXpController;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _iconController = TextEditingController(text: widget.category?.icon ?? '');
    _baseXpController = TextEditingController(
      text: widget.category?.baseXp.toString() ?? '100',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _baseXpController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.category != null;

  String _formatTypeName(String type) {
    switch (type) {
      case 'goal':
        return 'Goal';
      case 'task':
        return 'Task';
      case 'activity':
        return 'Activity';
      case 'life_area':
        return 'Life Area';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _formatTypeName(widget.categoryType);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: ActiveGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing
                        ? 'EDIT $typeLabel CATEGORY'
                        : 'NEW $typeLabel CATEGORY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name *
                  const Text(
                    'CATEGORY NAME *',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Business, Focus Sprint, Health',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter name'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Icon
                  const Text(
                    'ICON (OPTIONAL)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _iconController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'e.g. 🎯 or ⚡ or 🧠',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  const Text(
                    'DESCRIPTION (OPTIONAL)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Classification notes for this category',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                      'BASE XP REWARD (SCD TYPE-2 RULE VERSIONED)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                      controller: _baseXpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '100',
                        hintStyle: const TextStyle(color: Colors.white24),
                        suffixText: 'XP',
                        suffixStyle: const TextStyle(
                          color: Color(0xFFC6F135),
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) {
                          return 'Must be a positive integer';
                        }
                        return null;
                      },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveCategory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC6F135),
                            foregroundColor: const Color(0xFF020302),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF020302),
                                  ),
                                )
                              : Text(
                                  _isEditing
                                      ? 'SAVE CHANGES'
                                      : 'CREATE CATEGORY',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final icon = _iconController.text.trim();
      final baseXp = int.parse(_baseXpController.text.trim());

      if (_isEditing) {
        final catId = widget.category!.id;
        final oldBaseXp = widget.category!.baseXp;

        if (oldBaseXp != baseXp) {
          // Rule version changed! Publish new immutable rule version (ADR-003, Invariant #9)
          await widget.database.categoriesDao.publishNewRuleVersion(
            categoryId: catId,
            newBaseXp: baseXp,
            newActions: [],
            versionHlc: hlc,
          );
        }

        await widget.database.categoriesDao.updateCategory(
          categoryId: catId,
          name: name,
          description: desc.isNotEmpty ? desc : null,
          icon: icon.isNotEmpty ? icon : null,
          baseXp: baseXp,
          versionHlc: hlc,
        );

        await widget.database
            .into(widget.database.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                userId: widget.ownerId,
                op: 'update',
                entity: 'categories',
                entityId: catId,
                payloadJson: jsonEncode({
                  'name': name,
                  'description': desc,
                  'icon': icon,
                  'base_xp': baseXp,
                }),
                hlc: hlc,
                deviceId: 'local_device',
              ),
            );
      } else {
        final catId = Id.uuidV7().value;

        await widget.database.transaction(() async {
          await widget.database.categoriesDao.upsertCategory(
            CategoriesCompanion(
              id: drift.Value(catId),
              ownerId: drift.Value(widget.ownerId),
              name: drift.Value(name),
              categoryType: drift.Value(widget.categoryType),
              description: drift.Value(desc.isNotEmpty ? desc : null),
              icon: drift.Value(icon.isNotEmpty ? icon : null),
              baseXp: drift.Value(baseXp),
              isImmutable: const drift.Value(false),
              sortOrder: const drift.Value(0),
              versionHlc: drift.Value(hlc),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );

          // Freeze initial rule version snapshot (Invariant #9)
          final snapshot = {'base_xp': baseXp, 'actions': []};
          await widget.database
              .into(widget.database.categoryXpRuleVersions)
              .insert(
                CategoryXpRuleVersionsCompanion(
                  id: drift.Value(Id.uuidV7().value),
                  categoryId: drift.Value(catId),
                  snapshot: drift.Value(jsonEncode(snapshot)),
                  effectiveFrom: drift.Value(now),
                  createdAt: drift.Value(now),
                ),
              );

          await widget.database
              .into(widget.database.syncOutbox)
              .insert(
                SyncOutboxCompanion.insert(
                  userId: widget.ownerId,
                  op: 'upsert',
                  entity: 'categories',
                  entityId: catId,
                  payloadJson: jsonEncode({
                    'id': catId,
                    'owner_id': widget.ownerId,
                    'name': name,
                    'category_type': widget.categoryType,
                    'description': desc,
                    'icon': icon,
                    'base_xp': baseXp,
                  }),
                  hlc: hlc,
                  deviceId: 'local_device',
                ),
              );
        });
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Couldn\'t save category. Please check input.';
        });
      }
    }
  }
}
