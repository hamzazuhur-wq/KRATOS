import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../levels/data/level_detail_repository.dart';
import '../../tasks/presentation/create_task_dialog.dart';
import '../../xp/data/xp_analytics_dao.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';
import 'life_area_dashboard_screen.dart';

/// Vision & Long-Term screen.
///
/// Persistent domains of life backed by the real LifeAreas table and Drift database.
class LifeAreasScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const LifeAreasScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<LifeAreasScreen> createState() => _LifeAreasScreenState();
}

class _LifeAreasScreenState extends State<LifeAreasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VISION & LONG-TERM',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Define the direction your life is moving toward',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New Task',
            icon: const Icon(Icons.add_task, color: Color(0xFFC6F135)),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CreateTaskDialog(
                database: widget.database,
                ownerId: widget.ownerId,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Domain Categories',
            icon: const Icon(Icons.category_outlined, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) => CategoriesScreen(
                  database: widget.database,
                  ownerId: widget.ownerId,
                  initialCategoryType: 'life_area',
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
          StreamBuilder<List<LifeArea>>(
            stream:
                (widget.database.select(widget.database.lifeAreas)
                      ..where(
                        (area) =>
                            area.ownerId.equals(widget.ownerId) &
                            area.archivedAt.isNull() &
                            area.deletedAt.isNull(),
                      )
                      ..orderBy([
                        (area) => drift.OrderingTerm.asc(area.sortOrder),
                      ]))
                    .watch(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Could not load Vision domains data.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              final isLoading = !snapshot.hasData;
              final areas = snapshot.data ?? [];

              final Widget content;
              if (!snapshot.hasData) {
                content = const SizedBox.shrink();
              } else if (areas.isEmpty) {
                content = _EmptyVisionDomains(
                  onCreate: () => _openEditor(context),
                );
              } else {
                content = ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    // Hero Direction Statement
                    KratosGlassCard(
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC6F135)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFC6F135),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PERSISTENT DOMAINS',
                                    style: TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Shape your long-term focus across core life domains.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DOMAINS OF LIFE',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          '${areas.length} ACTIVE',
                          style: const TextStyle(
                            color: Color(0xFFC6F135),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...areas.map(
                      (area) => _DomainCard(
                        database: widget.database,
                        ownerId: widget.ownerId,
                        area: area,
                        onOpen: () => Navigator.of(context).push(
                          KratosPageRoute<void>(
                            page: LifeAreaDashboardScreen(
                              database: widget.database,
                              ownerId: widget.ownerId,
                              area: area,
                            ),
                          ),
                        ),
                        onEdit: () => _openEditor(context, area: area),
                        onArchive: () => _archive(context, area),
                      ),
                    ),
                  ],
                );
              }

              return SkeletonReveal(
                loading: isLoading,
                skeleton: const LifeAreasPageSkeleton(),
                child: content,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.add),
        label: const Text(
          'NEW DOMAIN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {LifeArea? area}) async {
    final result = await showModalBottomSheet<_LifeAreaDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LifeAreaEditor(
        database: widget.database,
        ownerId: widget.ownerId,
        area: area,
      ),
    );
    if (result == null || !context.mounted) return;

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();
    if (area == null) {
      final newAreaId = Id.uuidV7().value;
      await widget.database
          .into(widget.database.lifeAreas)
          .insert(
            LifeAreasCompanion.insert(
              id: newAreaId,
              ownerId: widget.ownerId,
              name: result.name,
              description: drift.Value(result.description),
              categoryId: drift.Value(result.categoryId),
              color: const drift.Value(null),
              icon: const drift.Value(null),
              sortOrder: 0,
              archivedAt: const drift.Value(null),
              deletedAt: const drift.Value(null),
              deletedBy: const drift.Value(null),
              deletedReason: const drift.Value(null),
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (result.startingXp > 0) {
        final writer = DriftXpLedgerWriter(widget.database);
        await writer.recordEvent(
          ownerId: Id(widget.ownerId),
          idempotencyKey: Id.uuidV7(),
          sourceType: 'admin',
          sourceId: Id(newAreaId),
          action: 'admin_adjust',
          basePoints: result.startingXp,
          allocationRatios: [
            AllocationRatio(lifeAreaId: Id(newAreaId), percentage: 100.0),
          ],
          clock: Hlc.now(Id.uuidV7()),
          deviceId: const Id('device-local'),
        );
      }
    } else {
      await (widget.database.update(
        widget.database.lifeAreas,
      )..where((row) => row.id.equals(area.id))).write(
        LifeAreasCompanion(
          name: drift.Value(result.name),
          description: drift.Value(result.description),
          categoryId: drift.Value(result.categoryId),
          versionHlc: drift.Value(hlc),
          updatedAt: drift.Value(now),
        ),
      );
    }
  }

  Future<void> _archive(BuildContext context, LifeArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'Archive Domain',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to archive "${area.name}"? It will be hidden from the active dashboard.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await (widget.database.update(
        widget.database.lifeAreas,
      )..where((row) => row.id.equals(area.id))).write(
        LifeAreasCompanion(
          archivedAt: drift.Value(DateTime.now().toUtc()),
          versionHlc: drift.Value(Hlc.now(Id.uuidV7()).toString()),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );
    }
  }
}

class _DomainCard extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final LifeArea area;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _DomainCard({
    required this.database,
    required this.ownerId,
    required this.area,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KratosGlassCard(
        dashboardGlass: true,
        accentColor: const Color(0xFFC6F135),
        borderRadius: BorderRadius.circular(20),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.visibility,
                          color: Color(0xFFC6F135),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              area.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (area.description != null &&
                                area.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                area.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      KratosPopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white38),
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'archive') onArchive();
                        },
                        itemBuilder: (_) => const [
                          KratosPopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16, color: Colors.white70),
                                SizedBox(width: 8),
                                Text('Edit', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          KratosPopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.archive,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Archive',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Stats badges row
                  FutureBuilder<(int xp, int activeGoals, int tasksCount)>(
                    future: _loadDomainStats(),
                    builder: (context, snapshot) {
                      final xp = snapshot.data?.$1 ?? 0;
                      final goals = snapshot.data?.$2 ?? 0;
                      final tasks = snapshot.data?.$3 ?? 0;

                      return Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _StatChip(
                                    icon: Icons.bolt,
                                    label: '$xp XP',
                                    color: const Color(0xFFC6F135),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatChip(
                                    icon: Icons.track_changes,
                                    label: '$goals Goals',
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatChip(
                                    icon: Icons.task_alt,
                                    label: '$tasks Tasks',
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFC6F135),
                            size: 20,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<(int, int, int)> _loadDomainStats() async {
    final xpDao = XpAnalyticsDao(database);
    final xp = await xpDao.totalXpForLifeArea(area.id);
    final goals =
        await (database.select(database.goals)..where(
              (g) =>
                  g.ownerId.equals(ownerId) &
                  g.lifeAreaId.equals(area.id) &
                  g.status.equals('active') &
                  g.deletedAt.isNull(),
            ))
            .get();
    final tasks =
        await (database.select(database.tasks)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.lifeAreaId.equals(area.id) &
                  t.deletedAt.isNull(),
            ))
            .get();
    return (xp, goals.length, tasks.length);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyVisionDomains extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyVisionDomains({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 56,
            color: Colors.white24,
          ),
          const SizedBox(height: 14),
          const Text(
            'No Vision Domains yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first domain to anchor your long-term focus and direction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6F135),
              foregroundColor: const Color(0xFF0D0D0D),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Create Vision Domain',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LifeAreaDraft {
  final String name;
  final String? description;
  final String? categoryId;
  final int? startingLevel;
  final int startingXp;

  const _LifeAreaDraft(
    this.name,
    this.description,
    this.categoryId, {
    this.startingLevel,
    this.startingXp = 0,
  });
}

class _LifeAreaEditor extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final LifeArea? area;
  const _LifeAreaEditor({
    required this.database,
    required this.ownerId,
    this.area,
  });

  @override
  State<_LifeAreaEditor> createState() => _LifeAreaEditorState();
}

class _LifeAreaEditorState extends State<_LifeAreaEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _categoryId;
  LevelDetailData? _selectedLevel;
  int _startingXp = 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.area?.name ?? '');
    _description = TextEditingController(text: widget.area?.description ?? '');
    _categoryId = widget.area?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        left: 20,
        right: 20,
        top: 14,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFC6F135),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.area == null
                          ? 'CREATE VISION DOMAIN'
                          : 'EDIT VISION DOMAIN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'Core pillar of life, focus, and mastery',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              key: const Key('life_area_name_input'),
              controller: _name,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Domain Name *',
                labelStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                hintText: 'e.g. Physical Mastery, Software Architecture',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC6F135)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Category>>(
              future: widget.database.categoriesDao.categoriesByType(
                widget.ownerId,
                'life_area',
              ),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const <Category>[];
                final selected = categories
                    .where((c) => c.id == _categoryId)
                    .firstOrNull;
                return InkWell(
                  key: const Key('life_area_category_picker'),
                  onTap: categories.isEmpty
                      ? null
                      : () async {
                          final picked = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: const Color(0xFF161616),
                            builder: (_) => ListView(
                              padding: const EdgeInsets.all(16),
                              children: categories
                                  .map(
                                    (c) => ListTile(
                                      title: Text(
                                        c.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(context, c.id),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _categoryId = picked);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category (optional)',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected?.name ??
                                  (categories.isEmpty
                                      ? 'No categories'
                                      : 'Select category'),
                              style: TextStyle(
                                color: selected == null
                                    ? Colors.white38
                                    : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            if (widget.area == null) ...[
              // Starting Level Picker
              FutureBuilder<List<LevelDetailData>>(
                future: LevelDetailRepository(widget.database)
                    .getAllLevelsWithDetails(widget.ownerId),
                builder: (context, snapshot) {
                  final levels = snapshot.data ?? const <LevelDetailData>[];
                  return InkWell(
                    key: const Key('starting_level_picker'),
                    onTap: levels.isEmpty
                        ? null
                        : () async {
                            final picked =
                                await showModalBottomSheet<LevelDetailData>(
                                  context: context,
                                  backgroundColor: const Color(0xFF161616),
                                  builder: (_) => ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'SELECT STARTING LEVEL',
                                          style: TextStyle(
                                            color: Color(0xFFC6F135),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      ...levels.map(
                                        (lvl) => ListTile(
                                          title: Text(
                                            lvl.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${lvl.tier} â€¢ Level ${lvl.level} (${lvl.lowerXp} - ${lvl.upperXp} XP)',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onTap: () =>
                                              Navigator.pop(context, lvl),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                            if (picked != null) {
                              setState(() {
                                _selectedLevel = picked;
                                _startingXp = picked.lowerXp;
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Starting Level (optional)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedLevel != null
                                    ? '${_selectedLevel!.name} (${_selectedLevel!.tier})'
                                    : (levels.isEmpty
                                          ? 'No levels configured'
                                          : 'Select starting level'),
                                style: TextStyle(
                                  color: _selectedLevel == null
                                      ? Colors.white38
                                      : const Color(0xFFC6F135),
                                  fontWeight: _selectedLevel == null
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          _selectedLevel != null
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedLevel = null;
                                      _startingXp = 0;
                                    });
                                  },
                                )
                              : const Icon(
                                  Icons.expand_more,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_selectedLevel != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'STARTING XP',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '$_startingXp XP',
                            style: const TextStyle(
                              color: Color(0xFFC6F135),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFC6F135),
                          thumbColor: const Color(0xFFC6F135),
                          inactiveTrackColor: Colors.white12,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _startingXp.toDouble().clamp(
                            _selectedLevel!.lowerXp.toDouble(),
                            _selectedLevel!.upperXp.toDouble(),
                          ),
                          min: _selectedLevel!.lowerXp.toDouble(),
                          max:
                              _selectedLevel!.upperXp.toDouble() >
                                  _selectedLevel!.lowerXp.toDouble()
                              ? _selectedLevel!.upperXp.toDouble()
                              : (_selectedLevel!.lowerXp.toDouble() + 1),
                          divisions:
                              (_selectedLevel!.upperXp -
                                      _selectedLevel!.lowerXp) >
                                  0
                              ? 20
                              : null,
                          onChanged: (val) {
                            setState(() => _startingXp = val.round());
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedLevel!.lowerXp} XP',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '${_selectedLevel!.upperXp} XP',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            TextField(
              key: const Key('life_area_description_input'),
              controller: _description,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Direction & Vision Description',
                labelStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                hintText: 'What is your highest standard and vision for this life area?',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC6F135)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('save_life_area_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: const Color(0xFF0D0D0D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final name = _name.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(context).pop(
                        _LifeAreaDraft(
                          name,
                          _description.text.trim().isEmpty
                              ? null
                              : _description.text.trim(),
                          _categoryId,
                          startingLevel: _selectedLevel?.level,
                          startingXp: _startingXp,
                        ),
                      );
                    },
                    child: Text(
                      widget.area == null ? 'CREATE DOMAIN' : 'SAVE CHANGES',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
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
  );
}
