import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../data/skills_repository.dart';
import '../domain/skill_models.dart';

class SkillDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String skillId;
  const SkillDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.skillId,
  });
  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  late final DriftSkillsRepository _repository;
  Skill? _skill;
  SkillGroup? _group;
  List<String> _lifeAreas = const [];
  List<_Usage> _usage = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = DriftSkillsRepository(widget.database);
    _load();
  }

  Future<void> _load() async {
    try {
      final skill = await widget.database.skillsDao.findById(widget.skillId);
      if (skill == null) throw StateError('Skill not found');
      final groups = await _repository.listGroups(widget.ownerId);
      final links = await widget.database.skillsDao.lifeAreasForSkill(
        widget.skillId,
      );
      final areas = await widget.database
          .select(widget.database.lifeAreas)
          .get();
      final areaNames = links
          .map(
            (link) => areas
                .where((area) => area.id == link.lifeAreaId)
                .map((area) => area.name)
                .firstOrNull,
          )
          .whereType<String>()
          .toList();
      final attachmentLinks = await widget.database.attachmentLinksDao
          .forAttachment(widget.skillId, 'skill');
      final usage = <_Usage>[];
      final linkedActivityIds = <String>{};
      final linkedTaskIds = <String>{};
      for (final link in attachmentLinks) {
        String? title;
        switch (link.entityKind) {
          case 'goal':
            title =
                (await (widget.database.select(widget.database.goals)
                          ..where((row) => row.id.equals(link.entityId)))
                        .getSingleOrNull())
                    ?.title;
            break;
          case 'project':
            title =
                (await (widget.database.select(widget.database.projects)
                          ..where((row) => row.id.equals(link.entityId)))
                        .getSingleOrNull())
                    ?.title;
            break;
          case 'task':
            linkedTaskIds.add(link.entityId);
            title =
                (await (widget.database.select(widget.database.tasks)
                          ..where((row) => row.id.equals(link.entityId)))
                        .getSingleOrNull())
                    ?.title;
            break;
          case 'activity':
            linkedActivityIds.add(link.entityId);
            title =
                (await (widget.database.select(widget.database.activities)
                          ..where((row) => row.id.equals(link.entityId)))
                        .getSingleOrNull())
                    ?.name;
            break;
          case 'session':
            title = 'Session ${link.entityId.substring(0, 8)}';
            break;
        }
        usage.add(_Usage(link.entityKind, title ?? link.entityId));
      }
      // Sessions inherit Skill attribution through their existing Task or
      // Activity parent. This keeps one session model and avoids inventing a
      // second XP/attribution system just for Skills.
      if (linkedActivityIds.isNotEmpty || linkedTaskIds.isNotEmpty) {
        final sessions =
            await (widget.database.select(widget.database.sessions)
                  ..where(
                    (session) =>
                        session.ownerId.equals(widget.ownerId) &
                        session.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (session) => OrderingTerm.desc(session.startedAt),
                  ]))
                .get();
        for (final session in sessions) {
          if ((session.activityId != null &&
                  linkedActivityIds.contains(session.activityId)) ||
              (session.taskId != null &&
                  linkedTaskIds.contains(session.taskId))) {
            final duration = session.durationMs == null
                ? ''
                : ' Â· ${(session.durationMs! / 60000).round()} min';
            usage.add(
              _Usage(
                'session',
                'Session ${session.id.substring(0, 8)}$duration',
              ),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _skill = skill;
          _group = groups
              .where((group) => group.id == skill.groupId)
              .firstOrNull;
          _lifeAreas = areaNames;
          _usage = usage;
          _loading = false;
          _error = null;
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

  Future<void> _edit() async {
    final skill = _skill;
    if (skill == null) return;
    final draft = await showDialog<_EditDraft>(
      context: context,
      builder: (_) => _EditDialog(skill: skill),
    );
    if (draft == null) return;
    await _repository.updateSkill(
      skill: skill,
      name: draft.name,
      description: draft.description,
      groupId: skill.groupId,
      masteryLevel: draft.masteryLevel,
    );
    await _load();
  }

  Future<void> _toggleArchive() async {
    final skill = _skill;
    if (skill == null) return;
    if (skill.archivedAt == null) {
      await _repository.archiveSkill(skill);
    } else {
      await _repository.restoreSkill(skill);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final skill = _skill;
    return Scaffold(
      backgroundColor: const Color(0xFF020302),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(skill?.name.toUpperCase() ?? 'SKILL'),
        actions: [
          if (skill != null)
            IconButton(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
          if (skill != null)
            IconButton(
              onPressed: _toggleArchive,
              icon: Icon(
                skill.archivedAt == null
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
              ),
              tooltip: skill.archivedAt == null ? 'Archive' : 'Restore',
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Unable to load this skill.',
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (skill != null)
                  _Hero(skill: skill, group: _group, lifeAreas: _lifeAreas),
                const SizedBox(height: 16),
                if (skill != null) _MasterySection(level: skill.masteryLevel),
                const SizedBox(height: 16),
                _UsageSection(usage: _usage),
              ],
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Skill skill;
  final SkillGroup? group;
  final List<String> lifeAreas;
  const _Hero({
    required this.skill,
    required this.group,
    required this.lifeAreas,
  });
  @override
  Widget build(BuildContext context) {
    final mastery = SkillMastery.fromValue(skill.masteryLevel);
    final color = _masteryColor(skill.masteryLevel);
    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            skill.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [if (group != null) group!.name, ...lifeAreas].join(' Â· '),
            style: const TextStyle(color: Colors.white54),
          ),
          if (skill.description != null) ...[
            const SizedBox(height: 16),
            Text(
              skill.description!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                mastery.roman,
                style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                mastery.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasterySection extends StatelessWidget {
  final int level;
  const _MasterySection({required this.level});
  @override
  Widget build(BuildContext context) => KratosGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MASTERY',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: SkillMastery.values
              .map(
                (mastery) => Column(
                  children: [
                    Text(
                      mastery.roman,
                      style: TextStyle(
                        color: mastery.value == level
                            ? _masteryColor(level)
                            : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      mastery.label,
                      style: TextStyle(
                        color: mastery.value == level
                            ? Colors.white70
                            : Colors.white24,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _UsageSection extends StatelessWidget {
  final List<_Usage> usage;
  const _UsageSection({required this.usage});
  @override
  Widget build(BuildContext context) => KratosGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'USED IN',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        if (usage.isEmpty)
          const Text(
            'No linked goals, projects, tasks, activities or sessions yet.',
            style: TextStyle(color: Colors.white54),
          )
        else
          ...usage.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, color: Color(0xFFEEFF08)),
              title: Text(
                item.title,
                style: const TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                item.kind.toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Usage {
  final String kind;
  final String title;
  const _Usage(this.kind, this.title);
}

class _EditDraft {
  final String name;
  final String? description;
  final int masteryLevel;
  const _EditDraft(this.name, this.description, this.masteryLevel);
}

class _EditDialog extends StatefulWidget {
  final Skill skill;
  const _EditDialog({required this.skill});
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late int _mastery;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.skill.name);
    _description = TextEditingController(text: widget.skill.description ?? '');
    _mastery = widget.skill.masteryLevel;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('EDIT SKILL'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _description,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ...SkillMastery.values.map(
              (m) => ButtonSegment(value: m.value, label: Text(m.roman)),
            ),
          ],
          selected: {_mastery},
          onSelectionChanged: (s) => setState(() => _mastery = s.first),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _EditDraft(
            _name.text.trim(),
            _description.text.trim().isEmpty ? null : _description.text.trim(),
            _mastery,
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}

Color _masteryColor(int level) => const [
  Color(0xFFB87333),
  Color(0xFFC0C0C0),
  Color(0xFFFFD700),
  Color(0xFFB9EAF5),
  Color(0xFFB9F2FF),
][level.clamp(1, 5) - 1];

