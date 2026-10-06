import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../data/drift/app_database.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../data/projects_repository.dart';
import '../domain/project_models.dart';
import 'new_project_screen.dart';
import 'project_detail_screen.dart';

/// Level 1: Projects Dashboard â€” Liquid Glass / Dark Volcanic command center.
class ProjectsScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const ProjectsScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsRepository _repository;

  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, active, paused, completed
  String? _selectedLifeAreaId;
  String? _selectedGoalId;
  String? _selectedSkillId;

  List<LifeArea> _lifeAreas = [];
  List<Goal> _goals = [];
  List<Skill> _skills = [];
  bool _filtersLoaded = false;

  @override
  void initState() {
    super.initState();
    _repository = ProjectsRepository(
      database: widget.database,
      xpLedgerWriter: DriftXpLedgerWriter(widget.database),
    );
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final areas =
        await (widget.database.select(widget.database.lifeAreas)
              ..where(
                (a) => a.ownerId.equals(widget.ownerId) & a.deletedAt.isNull(),
              )
              ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
            .get();

    final goals =
        await (widget.database.select(widget.database.goals)
              ..where(
                (g) =>
                    g.ownerId.equals(widget.ownerId) &
                    g.parentId.isNull() &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => OrderingTerm.asc(g.title)]))
            .get();

    final skills = await widget.database.skillsDao.listSkills(widget.ownerId);

    if (mounted) {
      setState(() {
        _lifeAreas = areas;
        _goals = goals;
        _skills = skills;
        _filtersLoaded = true;
      });
    }
  }

  void _navigateToNewProject() {
    Navigator.of(context).push(
      KratosPageRoute(
        page: NewProjectScreen(
          database: widget.database,
          ownerId: widget.ownerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: KratosSectionHeader(
          eyebrow: 'WORKSPACES // TIMELINES',
          title: 'Projects Command',
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: KratosTheme.electricLime.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: KratosTheme.electricLime.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: KratosTheme.electricLime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ACTIVE EXECUTION',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: KratosTheme.electricLime,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: const [
          SizedBox(width: 12),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          StreamBuilder<List<ProjectWithDetails>>(
            stream: _repository.watchProjects(
              widget.ownerId,
              query: _searchQuery,
              status: _selectedStatus,
              lifeAreaId: _selectedLifeAreaId,
              goalId: _selectedGoalId,
              skillId: _selectedSkillId,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load projects: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              final projects = snapshot.data ?? [];

              return KratosPageEntrance(
                child: CustomScrollView(
                  slivers: [
                    // Search & Filter controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSearchField(),
                          const SizedBox(height: 12),
                          _buildStatusFilterRow(),
                          if (_filtersLoaded) ...[
                            const SizedBox(height: 10),
                            _buildDropdownFiltersRow(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Content: Empty or List/Grid
                  if (!snapshot.hasData)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: KratosShimmer(
                          child: Column(
                            children: [
                              ProjectCardSkeleton(),
                              SizedBox(height: 12),
                              ProjectCardSkeleton(),
                              SizedBox(height: 12),
                              ProjectCardSkeleton(),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: KratosEmptyState(
                          icon: Icons.folder_special_outlined,
                          title: 'NO PROJECTS FOUND',
                          subtitle: 'Create a project workspace to orchestrate tasks & roadmaps.',
                          actionLabel: 'Create Project',
                          onAction: _navigateToNewProject,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.crossAxisExtent >= 600;
                          if (isWide) {
                            return SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 360,
                                    mainAxisExtent: 142,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, idx) =>
                                    _buildProjectCard(projects[idx]),
                                childCount: projects.length,
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildProjectCard(projects[idx]),
                              ),
                              childCount: projects.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToNewProject,
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.add),
        label: const Text(
          'New Project',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // â”€â”€â”€ Filter Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: TextStyle(
        color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: 'Search projects by title or description...',
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                  size: 18,
                ),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC6F135)),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statuses = [
      {'key': 'all', 'label': 'All'},
      {'key': 'active', 'label': 'Active'},
      {'key': 'paused', 'label': 'Paused'},
      {'key': 'completed', 'label': 'Completed'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((item) {
          final isSelected = _selectedStatus == item['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item['label']!),
              selected: isSelected,
              selectedColor: const Color(0xFFC6F135),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF0D0D0D)
                    : (isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFC6F135)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedStatus = item['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Life Area Filter
          if (_lifeAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KratosDropdown<String?>(
                value: _selectedLifeAreaId,
                hint: 'Life Area',
                prefixIcon: Icons.public,
                items: [
                  const KratosDropdownItem(value: null, label: 'All Areas'),
                  ..._lifeAreas.map(
                    (a) => KratosDropdownItem(
                      value: a.id,
                      label: a.name,
                      leading: Text(
                        a.icon ?? 'ðŸŒ',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedLifeAreaId = val),
              ),
            ),

          // Goal Filter
          if (_goals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KratosDropdown<String?>(
                value: _selectedGoalId,
                hint: 'Goal',
                prefixIcon: Icons.track_changes,
                items: [
                  const KratosDropdownItem(value: null, label: 'All Goals'),
                  ..._goals.map(
                    (g) => KratosDropdownItem(value: g.id, label: g.title),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedGoalId = val),
              ),
            ),

          // Skill Filter
          if (_skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KratosDropdown<String?>(
                value: _selectedSkillId,
                hint: 'Skill',
                prefixIcon: Icons.bolt,
                items: [
                  const KratosDropdownItem(value: null, label: 'All Skills'),
                  ..._skills.map(
                    (s) => KratosDropdownItem(
                      value: s.id,
                      label: s.name,
                      leading: Text(
                        s.icon ?? 'âš¡',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSkillId = val),
              ),
            ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Project Card Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildProjectCard(ProjectWithDetails item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = item.project;
    final romanDiff = ProjectDifficulty.toRoman(p.difficulty);

    return KratosSpringCard(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          KratosPageRoute(
            page: ProjectDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              projectId: p.id,
            ),
          ),
        );
      },
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.interactive,
        borderRadius: BorderRadius.circular(14),
        interactive: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Row 1: Badges + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: KratosTheme.electricLime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: KratosTheme.electricLime.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'DIFF $romanDiff',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: KratosTheme.electricLime,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 9,
                    ),
                  ),
                ),
                if (item.lifeArea != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        item.lifeArea!.name,
                        style: const TextStyle(
                          color: Color(0xFF979C92),
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                _buildCardStatusBadge(p.status),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Title
            Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Row 3: Progress bar + stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.completedTaskCount}/${item.taskCount} tasks · ${item.activityCount} acts',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFF686D65),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                KratosProgressBar(
                  value: (item.progress / 100.0).clamp(0.0, 1.0),
                  label: 'PROGRESS',
                  showPercentage: true,
                  height: 4,
                  fillColor: p.status.toLowerCase() == 'completed'
                      ? KratosTheme.electricLime
                      : const Color(0xFF00E5FF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStatusBadge(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'completed':
        c = KratosTheme.electricLime;
        break;
      case 'paused':
        c = const Color(0xFFE5C07B);
        break;
      default:
        c = const Color(0xFF00E5FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
