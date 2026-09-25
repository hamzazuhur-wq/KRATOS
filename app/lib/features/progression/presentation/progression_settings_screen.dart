// Wave 6: Progression Settings screen.
// Displays the tier ladder, level curves preview, compound progression metrics,
// and interactive tier/level thresholds management with interactive slider controls.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../domain/life_area_progression_service.dart';
import '../domain/progression_calculator.dart';
import '../domain/progression_models.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../levels/presentation/create_level_screen.dart';

class ProgressionSettingsScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const ProgressionSettingsScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<ProgressionSettingsScreen> createState() =>
      _ProgressionSettingsScreenState();
}

class _ProgressionSettingsScreenState extends State<ProgressionSettingsScreen> {
  late Future<List<({String name, ProgressionInfo info})>> _progressions;
  late List<TierDefinitionSnapshot> _currentTiers;
  double _simulatorXp = 1500;

  @override
  void initState() {
    super.initState();
    _currentTiers = List.from(ProgressionCalculator.defaultTiers);
    _progressions = _loadProgressions();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    await widget.database.progressionDao.ensureSeeded();
    final dbTiers = await widget.database.progressionDao.allTiers();
    if (dbTiers.isNotEmpty && mounted) {
      setState(() {
        _currentTiers = dbTiers
            .map((t) => TierDefinitionSnapshot(
                  name: t.name,
                  entryXp: t.entryXp,
                  ordinal: t.ordinal,
                  icon: t.icon ?? '',
                  color: t.color ?? '#C6F135',
                ))
            .toList();
      });
    }
  }

  Future<List<({String name, ProgressionInfo info})>> _loadProgressions() async {
    final areas = await (widget.database.select(widget.database.lifeAreas)
          ..where((area) => area.ownerId.equals(widget.ownerId) &
              area.archivedAt.isNull() &
              area.deletedAt.isNull())
          ..orderBy([(area) => OrderingTerm.asc(area.sortOrder)]))
        .get();
    final service = LifeAreaProgressionService(widget.database);
    return Future.wait(areas.map((area) async => (
          name: area.name,
          info: await service.getProgressionForLifeArea(
            lifeAreaId: Id(area.id),
          ),
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020302),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'LEVELS & TIERS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Category Settings',
            icon: const Icon(Icons.tune_outlined, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CategoriesScreen(
                  database: widget.database,
                  ownerId: widget.ownerId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<({String name, ProgressionInfo info})>>(
        future: _progressions,
        builder: (context, snapshot) {
          final areas = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // 1. Interactive Progression Simulator
              _buildSimulatorCard(),
              const SizedBox(height: 20),

              // 2. Active Life Area Progressions
              if (areas.isNotEmpty) ...[
                const Text(
                  'YOUR ACTIVE LIFE AREAS PROGRESSION',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                for (final area in areas) ...[
                  Text(
                    area.name.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildProgressionCard(area.info),
                  const SizedBox(height: 16),
                ],
              ],

              // 3. Tier Thresholds & Ladder Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TIER & LEVEL DEFINITIONS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreateLevelScreen(
                              database: widget.database,
                              ownerId: widget.ownerId,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFC6F135)),
                        label: const Text(
                          'New Level',
                          style: TextStyle(
                            color: Color(0xFFC6F135),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openTierEditor(),
                        icon: const Icon(Icons.tune, size: 16, color: Colors.white70),
                        label: const Text(
                          'Edit Tier',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tier list
              for (var i = 0; i < _currentTiers.length; i++)
                _buildEditableTierTile(_currentTiers[i], i),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSimulatorCard() {
    final simulatedInfo = ProgressionCalculator.calculate(
      totalXp: _simulatorXp.round(),
      customTiers: _currentTiers,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC6F135).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: Color(0xFFC6F135), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'XP LEVEL SIMULATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC6F135).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_simulatorXp.round()} XP',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Result Pill
          Row(
            children: [
              Text(
                'Calculated Tier: ${simulatedInfo.tier}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'Level ${simulatedInfo.level}',
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Interactive Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFC6F135),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFFC6F135),
              overlayColor: const Color(0xFFC6F135).withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: _simulatorXp,
              min: 0,
              max: 50000,
              divisions: 100,
              onChanged: (val) => setState(() => _simulatorXp = val),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 XP (Level 1)', style: TextStyle(color: Colors.white24, fontSize: 10)),
              Text('50,000 XP (High Tier)', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionCard(ProgressionInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEVEL ${info.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC6F135)),
                ),
                child: Text(
                  info.tier.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: info.progressPct / 100.0,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC6F135)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total XP: ${info.totalXp}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${info.xpInLevel} / ${info.xpToNext} XP (${info.progressPct}%)',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTierTile(TierDefinitionSnapshot tier, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech_outlined,
                color: Color(0xFFC6F135),
                size: 22,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Entry threshold: ${tier.entryXp} XP',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tier.entryXp} XP',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white60),
                onPressed: () => _openTierEditor(tier: tier, index: index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openTierEditor({TierDefinitionSnapshot? tier, int? index}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TierEditorDialog(
        initialTier: tier,
        onSave: (newTier) async {
          setState(() {
            if (index != null && index < _currentTiers.length) {
              _currentTiers[index] = newTier;
            } else {
              _currentTiers.add(newTier);
            }
            _currentTiers.sort((a, b) => a.entryXp.compareTo(b.entryXp));
          });
          await widget.database.progressionDao.upsertTierDefinition(
            TierDefinitionsCompanion(
              name: Value(newTier.name),
              entryXp: Value(newTier.entryXp),
              ordinal: Value(newTier.ordinal),
              icon: Value(newTier.icon.isNotEmpty ? newTier.icon : null),
              color: Value(newTier.color.isNotEmpty ? newTier.color : null),
            ),
          );
          final hlc = Hlc.now(Id.uuidV7()).toString();
          await widget.database.into(widget.database.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              userId: widget.ownerId,
              op: 'upsert',
              entity: 'tier_definitions',
              entityId: newTier.name,
              payloadJson: jsonEncode({
                'name': newTier.name,
                'entry_xp': newTier.entryXp,
                'ordinal': newTier.ordinal,
                'icon': newTier.icon,
                'color': newTier.color,
              }),
              hlc: hlc,
              deviceId: 'local_device',
            ),
          );
        },
      ),
    );
  }
}

class _TierEditorDialog extends StatefulWidget {
  final TierDefinitionSnapshot? initialTier;
  final ValueChanged<TierDefinitionSnapshot> onSave;

  const _TierEditorDialog({
    this.initialTier,
    required this.onSave,
  });

  @override
  State<_TierEditorDialog> createState() => _TierEditorDialogState();
}

class _TierEditorDialogState extends State<_TierEditorDialog> {
  late final TextEditingController _nameController;
  late double _xpValue;
  String _selectedRank = 'Bronze';

  final List<String> _rankPresets = [
    'Bronze',
    'Silver',
    'Gold',
    'Crystal',
    'Diamond',
    'Mythic',
    'Master',
    'Grandmaster',
    'Custom Level',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialTier?.name ?? 'Bronze Tier',
    );
    _xpValue = widget.initialTier?.entryXp.toDouble() ?? 1500.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initialTier != null ? 'EDIT LEVEL / TIER' : 'NEW LEVEL / TIER',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Preset Dropdown
            const Text(
              'RANK PRESET',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRank,
                  dropdownColor: const Color(0xFF141414),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: _rankPresets.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRank = val;
                        if (_nameController.text.isEmpty || _rankPresets.contains(_nameController.text)) {
                          _nameController.text = '$val Tier';
                        }
                        // Set recommended threshold range
                        switch (val) {
                          case 'Bronze':
                            _xpValue = 1000;
                            break;
                          case 'Silver':
                            _xpValue = 3000;
                            break;
                          case 'Gold':
                            _xpValue = 7000;
                            break;
                          case 'Crystal':
                            _xpValue = 15000;
                            break;
                          case 'Diamond':
                            _xpValue = 30000;
                            break;
                          case 'Mythic':
                            _xpValue = 60000;
                            break;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Custom Name
            const Text(
              'LEVEL / TIER TITLE *',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Bronze Specialist, Silver Adept',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // 3. XP Threshold with Interactive Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'XP THRESHOLD SLIDER',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC6F135)),
                  ),
                  child: Text(
                    '${_xpValue.round()} XP',
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFC6F135),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFFC6F135),
                trackHeight: 6,
              ),
              child: Slider(
                value: _xpValue,
                min: 100,
                max: 75000,
                divisions: 150,
                onChanged: (val) => setState(() => _xpValue = val),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('100 XP (Starter)', style: TextStyle(color: Colors.white24, fontSize: 10)),
                Text('75,000 XP (Legendary)', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final title = _nameController.text.trim();
                      if (title.isEmpty) return;

                      widget.onSave(
                        TierDefinitionSnapshot(
                          name: title,
                          entryXp: _xpValue.round(),
                          ordinal: widget.initialTier?.ordinal ?? 1,
                          icon: 'shield_custom',
                          color: '#C6F135',
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: const Color(0xFF020302),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'SAVE LEVEL / TIER',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
