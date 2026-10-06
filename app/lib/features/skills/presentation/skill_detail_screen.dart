import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
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

class _Usage {
  final String title;
  final String type;
  const _Usage({required this.title, required this.type});
}

Color _masteryColor(int level) => const [
  Color(0xFFB87333),
  Color(0xFFC0C0C0),
  Color(0xFFFFD700),
  Color(0xFFB9EAF5),
  Color(0xFFC6F135),
][level.clamp(1, 5) - 1];

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  late final DriftSkillsRepository _repository;
  Skill? _skill;
  SkillGroup? _group;
  List<String> _lifeAreas = const [];
  final List<_Usage> _usage = const [];
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
          .map((id) => areas.where((a) => a.id == id.lifeAreaId).firstOrNull?.name)
          .whereType<String>()
          .toList();

      if (mounted) {
        setState(() {
          _skill = skill;
          _group = groups.where((g) => g.id == skill.groupId).firstOrNull;
          _lifeAreas = areaNames;
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

  Future<void> _edit() async {
    // TODO: implement full edit flow
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = _skill;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: KratosSectionHeader(
          eyebrow: 'CAPABILITY DETAILS',
          title: skill?.name ?? 'Loading...',
        ),
        actions: [
          if (skill != null)
            IconButton(
              onPressed: _edit,
              icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
              tooltip: 'Edit',
            ),
          if (skill != null)
            IconButton(
              onPressed: _toggleArchive,
              icon: Icon(
                skill.archivedAt == null
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
                color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
              ),
              tooltip: skill.archivedAt == null ? 'Archive' : 'Restore',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: KratosTheme.electricLime))
          else if (_error != null)
            Center(
              child: Text(
                'Unable to load this skill.',
                style: TextStyle(color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
              ),
            )
          else
            ListView(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mastery = SkillMastery.fromValue(skill.masteryLevel);
    final color = _masteryColor(skill.masteryLevel);
    
    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            skill.name,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [if (group != null) group!.name.toUpperCase(), ...lifeAreas.map((a) => a.toUpperCase())].join(' · '),
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              color: isDark ? Colors.white54 : KratosTheme.lightTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          if (skill.description != null && skill.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              skill.description!,
              style: TextStyle(
                color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      mastery.roman,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      mastery.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
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
}

class _MasterySection extends StatelessWidget {
  final int level;
  const _MasterySection({required this.level});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MASTERY PROGRESSION',
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: SkillMastery.values
                .map(
                  (mastery) => Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mastery.value == level
                              ? _masteryColor(level).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mastery.value == level
                                ? _masteryColor(level).withValues(alpha: 0.4)
                                : (isDark ? Colors.white12 : KratosTheme.lightBorderGlass),
                          ),
                        ),
                        child: Text(
                          mastery.roman,
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: mastery.value == level
                                ? _masteryColor(level)
                                : (isDark ? Colors.white38 : KratosTheme.lightTextMuted),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mastery.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mastery.value == level
                              ? (isDark ? Colors.white70 : KratosTheme.lightTextPrimary)
                              : (isDark ? Colors.white24 : KratosTheme.lightTextMuted.withValues(alpha: 0.5)),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
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
}

class _UsageSection extends StatelessWidget {
  final List<_Usage> usage;
  const _UsageSection({required this.usage});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONNECTED ASSETS',
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (usage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No linked goals, projects, tasks, activities or sessions yet.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...usage.map((u) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.account_tree_outlined,
                    color: isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime,
                  ),
                  title: Text(
                    u.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    u.type,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
