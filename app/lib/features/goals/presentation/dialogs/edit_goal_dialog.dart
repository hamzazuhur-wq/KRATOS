// ignore_for_file: public_member_api_docs
// Wave 4: Edit Goal Dialog.
// Allows updating goal title, description, status, life area, and category with outbox sync.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                const Text(
                  'EDIT GOAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'TITLE *',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 14),

                // Description
                const Text(
                  'DESCRIPTION',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Status
                const Text(
                  'STATUS',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['active', 'paused', 'stopped', 'completed'].map((status) {
                    final isSel = _selectedStatus.toLowerCase() == status;
                    return ChoiceChip(
                      label: Text(status.toUpperCase()),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) setState(() => _selectedStatus = status);
                      },
                      selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      labelStyle: TextStyle(
                        color: isSel ? const Color(0xFFC6F135) : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Life Area
                const Text(
                  'LIFE AREA',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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
                          label: Text(area.name),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setState(() => _selectedLifeAreaId = area.id);
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
                ),
                const SizedBox(height: 14),

                // Goal Category
                const Text(
                  'GOAL CATEGORY',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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
                          label: Text(cat.name),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategoryId = cat.id);
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
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6F135),
                          foregroundColor: const Color(0xFF020302),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF020302)),
                              )
                            : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
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
