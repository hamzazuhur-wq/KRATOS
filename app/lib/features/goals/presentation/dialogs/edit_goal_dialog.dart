// ignore_for_file: public_member_api_docs
// Wave 4: Edit Goal Dialog.
// Allows updating goal title, description, status, life area, and category with outbox sync.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';

class EditGoalDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Goal goal;
  final VoidCallback onSaved;

  const EditGoalDialog({
    super.key,
    required this.database,
    required this.ownerId,
    required this.goal,
    required this.onSaved,
  });

  @override
  State<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<EditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late String _selectedStatus;
  String? _selectedLifeAreaId;
  String? _selectedCategoryId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal.title);
    _descriptionController = TextEditingController(text: widget.goal.description ?? '');
    _selectedStatus = widget.goal.status;
    _selectedLifeAreaId = widget.goal.lifeAreaId;
    _selectedCategoryId = widget.goal.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;
    final surfaceColor = isDark ? const Color(0xFF0D0F0D).withValues(alpha: 0.94) : KratosTheme.lightSurface;
    final cardColor = isDark ? const Color(0xFF141714) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: KratosModalEntrance(
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor, width: 1),
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
                      color: isDark ? Colors.white24 : Colors.black26,
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
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: lime.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: lime,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'EDIT GOAL',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'TITLE *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: lime),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: lime),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Status
                Text(
                  'STATUS',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['active', 'paused', 'stopped', 'completed'].map((status) {
                    final isSel = _selectedStatus.toLowerCase() == status;
                    return ChoiceChip(
                      label: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: isSel ? (isDark ? const Color(0xFF020302) : Colors.white) : mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) setState(() => _selectedStatus = status);
                      },
                      selectedColor: lime,
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: isSel
                              ? lime
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Life Area
                Text(
                  'LIFE AREA',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<LifeArea>>(
                  stream: (widget.database.select(widget.database.lifeAreas)
                        ..where((l) => l.ownerId.equals(widget.ownerId) & l.deletedAt.isNull()))
                      .watch(),
                  builder: (context, snapshot) {
                    final areas = snapshot.data ?? [];
                    return Wrap(
                      spacing: 8,
                      children: areas.map((area) {
                        final isSel = _selectedLifeAreaId == area.id;
                        return ChoiceChip(
                          label: Text(
                            area.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: isSel ? (isDark ? const Color(0xFF020302) : Colors.white) : mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setState(() => _selectedLifeAreaId = area.id);
                          },
                          selectedColor: lime,
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: isSel
                                  ? lime
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Goal Category
                Text(
                  'GOAL CATEGORY',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<Category>>(
                  stream: widget.database.categoriesDao.watchCategoriesByType(widget.ownerId, 'goal'),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? [];
                    return Wrap(
                      spacing: 8,
                      children: cats.map((cat) {
                        final isSel = _selectedCategoryId == cat.id;
                        return ChoiceChip(
                          label: Text(
                            cat.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: isSel ? (isDark ? const Color(0xFF020302) : Colors.white) : mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategoryId = cat.id);
                          },
                          selectedColor: lime,
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: isSel
                                  ? lime
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mutedColor,
                          side: BorderSide(color: borderColor),
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
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lime,
                          foregroundColor: isDark ? const Color(0xFF020302) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? const Color(0xFF020302) : Colors.white),
                              )
                            : Text(
                                'SAVE CHANGES',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? const Color(0xFF020302) : Colors.white,
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final now = DateTime.now().toUtc();
      final isCompleted = _selectedStatus == 'completed';

      await widget.database.transaction(() async {
        await (widget.database.update(widget.database.goals)
              ..where((g) => g.id.equals(widget.goal.id)))
            .write(
          GoalsCompanion(
            title: drift.Value(_titleController.text.trim()),
            description: drift.Value(_descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null),
            status: drift.Value(_selectedStatus),
            lifeAreaId: drift.Value(_selectedLifeAreaId),
            categoryId: drift.Value(_selectedCategoryId),
            progress: isCompleted ? const drift.Value(1.0) : const drift.Value.absent(),
            completedAt: isCompleted ? drift.Value(now) : const drift.Value.absent(),
            versionHlc: drift.Value(hlc),
            updatedAt: drift.Value(now),
          ),
        );

        await widget.database.into(widget.database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: widget.ownerId,
            op: 'update',
            entity: 'goals',
            entityId: widget.goal.id,
            payloadJson: jsonEncode({
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'status': _selectedStatus,
              'life_area_id': _selectedLifeAreaId,
              'category_id': _selectedCategoryId,
            }),
            hlc: hlc,
            deviceId: 'local_device',
          ),
        );
      });

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save changes: $e';
        });
      }
    }
  }
}
