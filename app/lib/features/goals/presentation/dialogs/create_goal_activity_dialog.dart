// ignore_for_file: public_member_api_docs
// Wave 6: Create Activity Dialog inside Goal / Sub-goal context.
// Activities represent repeatable practice / drills / habits connected to real Activity Categories and XP.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';

class CreateGoalActivityDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Goal goalContext;
  final VoidCallback onActivityCreated;

  const CreateGoalActivityDialog({
    super.key,
    required this.database,
    required this.ownerId,
    required this.goalContext,
    required this.onActivityCreated,
  });

  @override
  State<CreateGoalActivityDialog> createState() => _CreateGoalActivityDialogState();
}

class _CreateGoalActivityDialogState extends State<CreateGoalActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _baseXpController = TextEditingController(text: '20');

  String? _selectedActivityCategoryId;
  final Set<String> _selectedSkillIds = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _baseXpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: KratosModalEntrance(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.94),
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

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141714),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEEFF08).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(Icons.repeat, color: Color(0xFFEEFF08), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ADD ACTIVITY TO GOAL',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Color(0xFFF3F1E8),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Inherited Context
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141714),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 13, color: Color(0xFFEEFF08)),
                      const SizedBox(width: 6),
                      const Text(
                        'LINKED TO GOAL: ',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.goalContext.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFFF3F1E8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name *
                const Text(
                  'ACTIVITY NAME * (RECURRING / PRACTICE DRILL)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFF3F1E8),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 30m LeetCode practice, 5km Run, Deep Reading',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF686D65),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141714),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEFF08)),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter activity name' : null,
                ),
                const SizedBox(height: 14),

                // Activity Category * (from Activity Categories, NOT Goal/Task)
                const Text(
                  'ACTIVITY CATEGORY * (SETTINGS → ACTIVITY CATEGORIES)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildActivityCategoryPicker(),
                const SizedBox(height: 14),

                // Base XP Award per Session
                const Text(
                  'BASE XP PER PRACTICE SESSION',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _baseXpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFFEEFF08),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'XP',
                    suffixStyle: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFFEEFF08),
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141714),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEFF08)),
                    ),
                  ),
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid XP' : null,
                ),
                const SizedBox(height: 14),

                // Skills Attribution
                const Text(
                  'SKILLS ATTRIBUTION (OPTIONAL)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSkillsPicker(),
                const SizedBox(height: 14),

                // Description
                const Text(
                  'NOTES / PRACTICE INSTRUCTIONS',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFF3F1E8),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Guidelines for executing this practice drill',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF686D65),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141714),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEFF08)),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
                ],

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF979C92),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveActivity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFF08),
                          foregroundColor: const Color(0xFF020302),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF020302)),
                              )
                            : const Text(
                                'CREATE ACTIVITY',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF020302),
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

  Widget _buildActivityCategoryPicker() {
    return StreamBuilder<List<Category>>(
      stream: widget.database.categoriesDao.watchCategoriesByType(widget.ownerId, 'activity'),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        if (cats.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('No Activity Categories found.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _seedDefaultActivityCategory,
                  child: const Text('+ Add Default', style: TextStyle(color: Color(0xFFC6F135), fontSize: 12)),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 8,
          children: cats.map((cat) {
            final isSel = _selectedActivityCategoryId == cat.id;
            return ChoiceChip(
              label: Text(cat.name),
              selected: isSel,
              onSelected: (val) {
                if (val) setState(() => _selectedActivityCategoryId = cat.id);
              },
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                color: isSel ? const Color(0xFFC6F135) : Colors.white70,
                fontSize: 11,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _seedDefaultActivityCategory() async {
    final catId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();

    await widget.database.categoriesDao.upsertCategory(
      CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: drift.Value(widget.ownerId),
        name: const drift.Value('Practice / Drill'),
        categoryType: const drift.Value('activity'),
        description: const drift.Value('Repeatable deliberate practice routine'),
        baseXp: const drift.Value(25),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    setState(() => _selectedActivityCategoryId = catId);
  }

  Widget _buildSkillsPicker() {
    return StreamBuilder<List<Skill>>(
      stream: widget.database.select(widget.database.skills).watch(),
      builder: (context, snapshot) {
        final skills = snapshot.data ?? [];
        if (skills.isEmpty) {
          return const Text('No skills available', style: TextStyle(color: Colors.white24, fontSize: 11));
        }

        return Wrap(
          spacing: 6,
          children: skills.map((s) {
            final isSel = _selectedSkillIds.contains(s.id);
            return FilterChip(
              label: Text(s.name),
              selected: isSel,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedSkillIds.add(s.id);
                  } else {
                    _selectedSkillIds.remove(s.id);
                  }
                });
              },
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.2),
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              labelStyle: TextStyle(color: isSel ? const Color(0xFFC6F135) : Colors.white60, fontSize: 11),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedActivityCategoryId == null) {
      setState(() => _errorMessage = 'Please select an Activity Category');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final activityId = Id.uuidV7().value;
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final baseXp = int.parse(_baseXpController.text.trim());

      final xpRuleBlob = jsonEncode({
        'goal_id': widget.goalContext.id,
        'base_xp': baseXp,
        'unit': 'session',
        'per_unit': baseXp,
        'skill_ids': _selectedSkillIds.toList(),
      });

      await widget.database.transaction(() async {
        await widget.database.activitiesDao.upsert(
          ActivitiesCompanion(
            id: drift.Value(activityId),
            ownerId: drift.Value(widget.ownerId),
            lifeAreaId: drift.Value(widget.goalContext.lifeAreaId),
            categoryId: drift.Value(_selectedActivityCategoryId),
            name: drift.Value(_nameController.text.trim()),
            description: drift.Value(_descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null),
            xpRule: drift.Value(xpRuleBlob),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        await widget.database.into(widget.database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: widget.ownerId,
            op: 'upsert',
            entity: 'activities',
            entityId: activityId,
            payloadJson: jsonEncode({
              'id': activityId,
              'owner_id': widget.ownerId,
              'life_area_id': widget.goalContext.lifeAreaId,
              'category_id': _selectedActivityCategoryId,
              'name': _nameController.text.trim(),
              'description': _descriptionController.text.trim(),
              'xp_rule': xpRuleBlob,
            }),
            hlc: hlc,
            deviceId: 'local_device',
          ),
        );
      });

      widget.onActivityCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to create activity: $e';
        });
      }
    }
  }
}
