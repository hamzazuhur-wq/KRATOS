// ignore_for_file: public_member_api_docs
// Wave 7: Attach Existing Project to Goal Dialog.
// Strict architectural adherence: selects an EXISTING project only; does NOT create new projects.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';

class AttachProjectDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Goal goal;
  final VoidCallback onProjectAttached;

  const AttachProjectDialog({
    super.key,
    required this.database,
    required this.ownerId,
    required this.goal,
    required this.onProjectAttached,
  });

  @override
  State<AttachProjectDialog> createState() => _AttachProjectDialogState();
}

class _AttachProjectDialogState extends State<AttachProjectDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedProjectId;
  bool _isAttaching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: KratosModalEntrance(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
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

            // Title
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
                  child: const Icon(Icons.folder_shared_outlined, color: Color(0xFFEEFF08), size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTACH EXISTING PROJECT',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Color(0xFFF3F1E8),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Select an existing project to align with this Goal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF979C92),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFF3F1E8),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search projects by title...',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF686D65),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF686D65), size: 18),
                filled: true,
                fillColor: const Color(0xFF141714),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Projects List
            Expanded(
              child: StreamBuilder<List<Project>>(
                stream: widget.database.projectsDao.allProjects(widget.ownerId).asStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFEEFF08)));
                  }

                  final all = snapshot.data!;
                  final matching = all.where((p) {
                    if (_searchQuery.isNotEmpty && !p.title.toLowerCase().contains(_searchQuery)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (matching.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_open, size: 40, color: Color(0xFF686D65)),
                          const SizedBox(height: 10),
                          const Text(
                            'No Matching Projects Found',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: Color(0xFFF3F1E8),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'New projects can be created from the Projects section.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF979C92),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RadioGroup<String>(
                    groupValue: _selectedProjectId,
                    onChanged: (val) => setState(() => _selectedProjectId = val),
                    child: ListView.builder(
                      itemCount: matching.length,
                      itemBuilder: (context, index) {
                        final project = matching[index];
                        final isAlreadyAttached = project.goalId == widget.goal.id;
                        final isSelected = _selectedProjectId == project.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEEFF08).withValues(alpha: 0.1)
                                : const Color(0xFF141714),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFEEFF08).withValues(alpha: 0.6)
                                  : (isAlreadyAttached
                                      ? const Color(0xFFEEFF08).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.06)),
                            ),
                          ),
                          child: ListTile(
                            onTap: isAlreadyAttached
                                ? null
                                : () => setState(() => _selectedProjectId = project.id),
                            leading: Icon(
                              Icons.folder_outlined,
                              color: isAlreadyAttached ? const Color(0xFFEEFF08) : const Color(0xFF979C92),
                              size: 20,
                            ),
                            title: Text(
                              project.title,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: isAlreadyAttached ? const Color(0xFF686D65) : const Color(0xFFF3F1E8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: project.description != null
                                ? Text(
                                    project.description!,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF686D65),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: isAlreadyAttached
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEFF08).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ALREADY LINKED',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: Color(0xFFEEFF08),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : Radio<String>(
                                    value: project.id,
                                    activeColor: const Color(0xFFEEFF08),
                                  ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
            ],

            const SizedBox(height: 16),
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
                    onPressed: _selectedProjectId == null || _isAttaching ? null : _attachProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEFF08),
                      foregroundColor: const Color(0xFF020302),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: _isAttaching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF020302)),
                          )
                        : const Text(
                            'ATTACH PROJECT',
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
  );
  }

  Future<void> _attachProject() async {
    if (_selectedProjectId == null) return;

    setState(() {
      _isAttaching = true;
      _errorMessage = null;
    });

    try {
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final now = DateTime.now().toUtc();

      await widget.database.transaction(() async {
        await (widget.database.update(widget.database.projects)
              ..where((p) => p.id.equals(_selectedProjectId!)))
            .write(
          ProjectsCompanion(
            goalId: drift.Value(widget.goal.id),
            lifeAreaId: drift.Value(widget.goal.lifeAreaId),
            versionHlc: drift.Value(hlc),
            updatedAt: drift.Value(now),
          ),
        );

        await widget.database.into(widget.database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: widget.ownerId,
            op: 'update',
            entity: 'projects',
            entityId: _selectedProjectId!,
            payloadJson: jsonEncode({
              'goal_id': widget.goal.id,
              'life_area_id': widget.goal.lifeAreaId,
            }),
            hlc: hlc,
            deviceId: 'local_device',
          ),
        );
      });

      widget.onProjectAttached();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAttaching = false;
          _errorMessage = 'Failed to attach project: $e';
        });
      }
    }
  }
}
