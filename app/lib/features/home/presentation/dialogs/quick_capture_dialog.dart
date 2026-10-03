import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';

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
      // First line as title, remainder as description
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
          const SnackBar(
            content: Text('Idea captured successfully'),
            backgroundColor: Color(0xFF1E281E),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: KratosModalEntrance(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
          color: const Color(0xFF111411).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
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
                    color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Color(0xFFC6F135),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'QUICK CAPTURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'What are you thinking or working on?...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFC6F135),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Foundation bar: voice capture foundation chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.mic_none, color: Colors.white38, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Voice ready',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openFullEditor,
                  child: const Text(
                    'Open Editor',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _captureQuick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F135),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Capture',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
}
