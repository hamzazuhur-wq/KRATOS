import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../../../domain/ids.dart';
import '../../../ideas/data/ideas_repository.dart';
import '../../../ideas/domain/idea_models.dart';
import '../../../ideas/presentation/idea_editor_screen.dart';

/// Rapid Capture modal for capturing thoughts, ideas, and tasks into KRATOS.
/// Foundation ready for future Voice Capture and AI structuring.
class QuickCaptureDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const QuickCaptureDialog({
    super.key,
    required this.database,
    required this.ownerId,
  });

  static Future<void> show(
    BuildContext context, {
    required AppDatabase database,
    required String ownerId,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => QuickCaptureDialog(database: database, ownerId: ownerId),
    );
  }

  @override
  State<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<QuickCaptureDialog> {
  final _textController = TextEditingController();
  late final IdeasRepository _ideasRepo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ideasRepo = IdeasRepository(widget.database);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _captureQuick() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final lines = text.split('\n');
      final title = lines.first;
      final description = lines.length > 1
          ? lines.sublist(1).join('\n').trim()
          : null;

      final blocks = (description != null && description.isNotEmpty)
          ? [
              IdeaBlock(
                id: Id.uuidV7().value,
                type: IdeaBlockType.paragraph,
                content: description,
              ),
            ]
          : null;

      await _ideasRepo.createIdea(
        ownerId: widget.ownerId,
        title: title,
        initialBlocks: blocks,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Idea captured successfully'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E281E)
                : KratosTheme.lightSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openFullEditor() async {
    final text = _textController.text.trim();
    final title = text.isNotEmpty ? text.split('\n').first : 'Untitled';

    final ideaId = await _ideasRepo.createIdea(
      ownerId: widget.ownerId,
      title: title,
    );

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        KratosMaterialPageRoute(
          builder: (_) => IdeaEditorScreen(
            database: widget.database,
            ownerId: widget.ownerId,
            ideaId: ideaId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lime.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bolt, color: lime, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'QUICK CAPTURE',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedColor, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  autofocus: true,
                  maxLines: 4,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What are you thinking or working on?...',
                    hintStyle: TextStyle(color: mutedColor, fontSize: 13),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: lime, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mic_none, color: mutedColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Voice ready',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: mutedColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openFullEditor,
                      child: Text(
                        'Open Editor',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KratosPressable(
                      onTap: _saving ? null : _captureQuick,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              )
                            : Text(
                                'Capture',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: isDark ? const Color(0xFF020302) : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  letterSpacing: 0.5,
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
    );
  }
}
