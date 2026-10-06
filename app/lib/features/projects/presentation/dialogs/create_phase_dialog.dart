import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../data/projects_repository.dart';

/// Modal dialog for adding a new Roadmap Phase to a Project.
/// Follows the Liquid Glass design language of CreateGoalDialog.
class CreatePhaseDialog extends StatefulWidget {
  final ProjectsRepository repository;
  final String ownerId;
  final String projectId;
  final String projectTitle;
  final int nextSortOrder;

  const CreatePhaseDialog({
    super.key,
    required this.repository,
    required this.ownerId,
    required this.projectId,
    required this.projectTitle,
    required this.nextSortOrder,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ProjectsRepository repository,
    required String ownerId,
    required String projectId,
    required String projectTitle,
    required int nextSortOrder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePhaseDialog(
        repository: repository,
        ownerId: ownerId,
        projectId: projectId,
        projectTitle: projectTitle,
        nextSortOrder: nextSortOrder,
      ),
    );
  }

  @override
  State<CreatePhaseDialog> createState() => _CreatePhaseDialogState();
}

class _CreatePhaseDialogState extends State<CreatePhaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  static const _phasePresets = [
    'Setup & Architecture',
    'Core MVP Features',
    'Integration & APIs',
    'Testing & Polish',
    'Launch & Review',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a phase name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.createPhase(
        projectId: widget.projectId,
        ownerId: widget.ownerId,
        name: name,
        description: _descriptionController.text.trim(),
        sortOrder: widget.nextSortOrder,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to create phase: $e';
        });
      }
    }
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

    final phaseNumStr = (widget.nextSortOrder + 1).toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: KratosModalEntrance(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
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
                    // Pill Grab Handle
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
                            color: lime.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: lime.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.alt_route,
                            color: lime,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADD ROADMAP PHASE',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lime.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'PHASE $phaseNumStr',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: lime,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.projectTitle,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: mutedColor,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Error Message if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 1. Phase Name
                    Text(
                      'PHASE NAME *',
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
                      controller: _nameController,
                      autofocus: true,
                      style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Phase $phaseNumStr: Core Architecture',
                        hintStyle: TextStyle(color: mutedColor),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: lime,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Preset suggestion chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _phasePresets.map((preset) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _nameController.text =
                                  'Phase $phaseNumStr: $preset';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: textColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 2. Phase Objectives / Deliverables
                    Text(
                      'OBJECTIVES & DELIVERABLES (OPTIONAL)',
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
                      maxLines: 3,
                      style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Key milestones, deliverables, or checklist definition...',
                        hintStyle: TextStyle(color: mutedColor),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: lime,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: mutedColor,
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(fontFamily: 'IBM Plex Mono', fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: KratosPressable(
                            onTap: _isSaving ? null : _submit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: lime,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: _isSaving
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'ADD PHASE',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
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
        ),
      ],
    );
  }
}
