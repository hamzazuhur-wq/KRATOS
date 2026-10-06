import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_text_prompt.dart';
import '../../../data/drift/app_database.dart';
import '../data/skills_repository.dart';
import '../domain/skill_models.dart';
import 'skill_detail_screen.dart';

class SkillsRegistryScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  const SkillsRegistryScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });
  @override
  State<SkillsRegistryScreen> createState() => _SkillsRegistryScreenState();
}

class _SkillsRegistryScreenState extends State<SkillsRegistryScreen> {
  late final DriftSkillsRepository _repository;
  final _searchController = TextEditingController();
  List<Skill> _skills = const [];
  List<SkillGroup> _groups = const [];
  String? _groupId;
  int? _masteryLevel;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = DriftSkillsRepository(widget.database);
    _searchController.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _searchController.removeListener(_reload);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final skills = await _repository.listSkills(
        widget.ownerId,
        query: _searchController.text,
        groupId: _groupId,
        masteryLevel: _masteryLevel,
      );
      final groups = await _repository.listGroups(widget.ownerId);
      if (mounted) {
        setState(() {
          _skills = skills;
          _groups = groups;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _manageGroups() async {
    final groups = await _repository.listGroups(
      widget.ownerId,
      includeArchived: true,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _GroupManagerDialog(
        groups: groups,
        onCreate: () async {
          final name = await _textDialog('New Skill Group', 'Group name');
          if (name != null && name.trim().isNotEmpty) {
            await _repository.createGroup(ownerId: widget.ownerId, name: name.trim());
            await _reload();
          }
        },
        onRename: (group) async {
          final name = await _textDialog('Rename Skill Group', 'Group name');
          if (name != null && name.trim().isNotEmpty) {
            await _repository.renameGroup(group: group, name: name);
          }
        },
        onArchive: (group) => _repository.archiveGroup(group),
        onRestore: (group) => _repository.restoreGroup(group),
      ),
    );
    await _reload();
  }

  Future<String?> _textDialog(String title, String label) =>
      KratosTextPrompt.show(context, title: title, label: label);

  Future<void> _openCreate() async {
    final lifeAreas =
        await (widget.database.select(widget.database.lifeAreas)
              ..where(
                (area) =>
                    area.ownerId.equals(widget.ownerId) &
                    area.deletedAt.isNull() &
                    area.archivedAt.isNull(),
              )
              ..orderBy([(area) => OrderingTerm.asc(area.name)]))
            .get();
    if (!mounted) return;
    final draft = await showModalBottomSheet<_SkillDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillSheet(groups: _groups, lifeAreas: lifeAreas),
    );
    if (draft == null) return;
    try {
      var groupId = draft.groupId;
      if (draft.createGroupName != null && draft.createGroupName!.isNotEmpty) {
        await _repository.createGroup(
          ownerId: widget.ownerId,
          name: draft.createGroupName!,
        );
        _groups = await _repository.listGroups(widget.ownerId);
        groupId = _groups
            .where(
              (group) =>
                  group.name.toLowerCase() ==
                  draft.createGroupName!.toLowerCase(),
            )
            .firstOrNull
            ?.id;
      }
      final newSkillId = await _repository.createSkill(
        ownerId: widget.ownerId,
        name: draft.name,
        description: draft.description,
        groupId: groupId,
        masteryLevel: draft.masteryLevel,
      );
      for (final lifeAreaId in draft.lifeAreaIds) {
        await _repository.attachSkillToLifeArea(
          ownerId: widget.ownerId,
          skillId: newSkillId,
          lifeAreaId: lifeAreaId,
        );
      }
      // Reset search and mastery filters, and select the group of the newly created skill
      _searchController.clear();
      _masteryLevel = null;
      _groupId = groupId;
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skill "${draft.name}" created successfully!'),
            backgroundColor: const Color(0xFF141714),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating skill: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openDetail(Skill skill) {
    Navigator.of(context)
        .push(
          KratosPageRoute(
            page: SkillDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              skillId: skill.id,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mastered = _skills.where((skill) => skill.masteryLevel == 5).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'SKILLS',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _manageGroups,
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Manage groups',
          ),
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: 'New skill',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFFEEFF08),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('New Skill'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            Text(
              'Build, track and master your capabilities.',
              style: TextStyle(
                color: isDark ? Colors.white60 : KratosTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Metric(label: 'SKILLS', value: '${_skills.length}'),
                const SizedBox(width: 10),
                _Metric(label: 'MASTERED', value: '$mastered'),
              ],
            ),
            const SizedBox(height: 16),
            // Futuristic Liquid Glass Search Input (No white underline)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121412) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search skills...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? const Color(0xFFC6F135) : const Color(0xFF658200),
                    size: 19,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: Icon(
                            Icons.clear,
                            color: isDark ? Colors.white54 : KratosTheme.lightTextMuted,
                            size: 18,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Liquid Glass Filters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                KratosDropdown<String?>(
                  value: _groupId,
                  hint: 'All Groups',
                  prefixIcon: Icons.category,
                  items: [
                    const KratosDropdownItem(value: null, label: 'All Groups'),
                    ..._groups.map(
                      (group) => KratosDropdownItem(value: group.id, label: group.name),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _groupId = value);
                    _reload();
                  },
                ),
                KratosDropdown<int?>(
                  value: _masteryLevel,
                  hint: 'All Mastery',
                  prefixIcon: Icons.auto_awesome,
                  items: [
                    const KratosDropdownItem(value: null, label: 'All Mastery'),
                    ...SkillMastery.values.map(
                      (mastery) => KratosDropdownItem(
                        value: mastery.value,
                        label: '${mastery.roman} ${mastery.label}',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _masteryLevel = value);
                    _reload();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const KratosShimmer(
                child: Column(
                  children: [
                    SkillCardSkeleton(),
                    SizedBox(height: 12),
                    SkillCardSkeleton(),
                    SizedBox(height: 12),
                    SkillCardSkeleton(),
                    SizedBox(height: 12),
                    SkillCardSkeleton(),
                  ],
                ),
              )
            else if (_error != null)
              _ErrorState(onRetry: _reload)
            else if (_skills.isEmpty)
              const _EmptyState()
            else
              ..._skills.map(
                (skill) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SkillCard(
                    skill: skill,
                    groupName: _groups
                        .where((group) => group.id == skill.groupId)
                        .firstOrNull
                        ?.name,
                    onTap: () => _openDetail(skill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}

class _SkillDraft {
  final String name;
  final String? description;
  final String? groupId;
  final int masteryLevel;
  final String? createGroupName;
  final List<String> lifeAreaIds;
  const _SkillDraft(
    this.name,
    this.description,
    this.groupId,
    this.masteryLevel,
    this.createGroupName,
    this.lifeAreaIds,
  );
}

class _GroupManagerDialog extends StatelessWidget {
  final List<SkillGroup> groups;
  final VoidCallback onCreate;
  final Future<void> Function(SkillGroup group) onRename;
  final Future<void> Function(SkillGroup group) onArchive;
  final Future<void> Function(SkillGroup group) onRestore;

  const _GroupManagerDialog({
    required this.groups,
    required this.onCreate,
    required this.onRename,
    required this.onArchive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF121412),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
    title: Row(
      children: [
        const Icon(Icons.folder_open_outlined, color: Color(0xFFC6F135), size: 20),
        const SizedBox(width: 8),
        const Text('SKILL GROUPS', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const Spacer(),
        IconButton(
          tooltip: 'Add Group',
          icon: const Icon(Icons.add_circle, color: Color(0xFFC6F135), size: 22),
          onPressed: () {
            Navigator.pop(context);
            onCreate();
          },
        ),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: groups.isEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text('No groups yet.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onCreate();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Create First Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F135),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            )
          : ListView(
              shrinkWrap: true,
              children: groups
                  .map(
                    (group) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder, color: Color(0xFFC6F135), size: 18),
                        title: Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          group.archivedAt == null ? 'Active' : 'Archived',
                          style: TextStyle(color: group.archivedAt == null ? Colors.white38 : Colors.amber, fontSize: 10),
                        ),
                        trailing: KratosPopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                          onSelected: (action) async {
                            if (action == 'rename') await onRename(group);
                            if (action == 'archive') await onArchive(group);
                            if (action == 'restore') await onRestore(group);
                            if (context.mounted) Navigator.pop(context);
                          },
                          itemBuilder: (_) => [
                            const KratosPopupMenuItem(
                              value: 'rename',
                              child: Text('Rename', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            KratosPopupMenuItem(
                              value: group.archivedAt == null ? 'archive' : 'restore',
                              child: Text(
                                group.archivedAt == null ? 'Archive' : 'Restore',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close', style: TextStyle(color: Colors.white60)),
      ),
    ],
  );
}

class _SkillSheet extends StatefulWidget {
  final List<SkillGroup> groups;
  final List<LifeArea> lifeAreas;
  const _SkillSheet({required this.groups, required this.lifeAreas});
  @override
  State<_SkillSheet> createState() => _SkillSheetState();
}

class _SkillSheetState extends State<_SkillSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _groupId;
  String? _newGroup;
  int _mastery = 1;
  final Set<String> _lifeAreaIds = {};

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;
    final surfaceColor = isDark ? const Color(0xFF0D0F0D).withValues(alpha: 0.96) : KratosTheme.lightSurface;
    final cardColor = isDark ? const Color(0xFF161816) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.psychology_outlined, color: lime, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW SKILL', style: TextStyle(fontFamily: 'Space Grotesk', color: lime, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text('Attribution capability in KRATOS', style: TextStyle(fontFamily: 'Inter', color: mutedColor, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: true,
              style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Skill Name *',
                labelStyle: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lime)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lime)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: KratosDropdownFormField<String?>(
                    initialValue: _groupId,
                    labelText: 'SKILL GROUP',
                    hint: 'No group',
                    prefixIcon: Icons.category_outlined,
                    items: [
                      const KratosDropdownItem<String?>(
                        value: null,
                        label: 'No group',
                      ),
                      ...widget.groups.map(
                        (g) => KratosDropdownItem(value: g.id, label: g.name),
                      ),
                    ],
                    onChanged: (val) => setState(() {
                      _groupId = val;
                      _newGroup = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Create New Group',
                  icon: Icon(Icons.add_circle_outline, color: lime),
                  onPressed: () async {
                    final val = await KratosTextPrompt.show(
                      context,
                      title: 'New Group',
                      label: 'Group Name',
                      confirmLabel: 'ADD',
                    );
                    if (val != null && val.isNotEmpty) {
                      setState(() {
                        _newGroup = val;
                        _groupId = null;
                      });
                    }
                  },
                ),
              ],
            ),
            if (_newGroup != null) ...[
              const SizedBox(height: 6),
              Text('Creating with new group: "$_newGroup"', style: TextStyle(fontFamily: 'IBM Plex Mono', color: lime, fontSize: 11)),
            ],
            const SizedBox(height: 14),
            Text('MASTERY LEVEL', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected) ? lime : cardColor,
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected) ? (isDark ? Colors.black : Colors.white) : textColor,
                ),
              ),
              segments: [
                ...SkillMastery.values.map(
                  (m) => ButtonSegment(value: m.value, label: Text(m.roman, style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              ],
              selected: {_mastery},
              onSelectionChanged: (sel) => setState(() => _mastery = sel.first),
            ),
            if (widget.lifeAreas.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('CONNECT TO LIFE AREAS', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.lifeAreas.map((area) {
                  final isSelected = _lifeAreaIds.contains(area.id);
                  return FilterChip(
                    label: Text(area.name, style: TextStyle(fontFamily: 'Inter', color: isSelected ? (isDark ? Colors.black : Colors.white) : textColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    selected: isSelected,
                    selectedColor: lime,
                    backgroundColor: cardColor,
                    checkmarkColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? lime : borderColor)),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _lifeAreaIds.add(area.id);
                        } else {
                          _lifeAreaIds.remove(area.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_name.text.trim().isNotEmpty) {
                    Navigator.pop(
                      context,
                      _SkillDraft(
                        _name.text.trim(),
                        _description.text.trim().isEmpty ? null : _description.text.trim(),
                        _groupId,
                        _mastery,
                        _newGroup,
                        _lifeAreaIds.toList(),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: isDark ? const Color(0xFF020302) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('CREATE SKILL', style: TextStyle(fontFamily: 'IBM Plex Mono', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final Skill skill;
  final String? groupName;
  final VoidCallback onTap;
  const _SkillCard({
    required this.skill,
    required this.groupName,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mastery = SkillMastery.fromValue(skill.masteryLevel);
    final color = _masteryColor(skill.masteryLevel);
    return KratosGlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                mastery.roman,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mastery.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (groupName != null)
                    Text(
                      groupName!.toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  if (skill.description != null)
                    Text(
                      skill.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : KratosTheme.lightTextMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
            ),
          ],
        ),
      ),
    ),
  );
  }
}

Color _masteryColor(int level) => const [
  Color(0xFFB87333),
  Color(0xFFC0C0C0),
  Color(0xFFFFD700),
  Color(0xFFB9EAF5),
  Color(0xFFB9F2FF),
][level.clamp(1, 5) - 1];

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFEEFF08),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(40),
    child: Center(
      child: Text(
        'No skills match these filters.',
        style: TextStyle(color: Colors.white54),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        const Text(
          'Unable to load skills.',
          style: TextStyle(color: Colors.white70),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}


