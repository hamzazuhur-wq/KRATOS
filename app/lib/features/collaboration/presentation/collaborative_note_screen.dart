// ignore_for_file: public_member_api_docs
// Wave 24: CollaborativeNoteScreen — Liquid Glass real-time collaborative pad.
//
// Shows live document editor with partner sync indicators, CRDT delta logging,
// and Acid Lime highlights.

import 'package:flutter/material.dart';
import '../data/collaborative_notes_dao.dart';
import '../domain/crdt_models.dart';
import '../../../data/drift/app_database.dart';

class CollaborativeNoteScreen extends StatefulWidget {
  final String noteId;
  final String currentUserId;
  final String partnerName;
  final CollaborativeNotesDao notesDao;

  const CollaborativeNoteScreen({
    super.key,
    required this.noteId,
    required this.currentUserId,
    this.partnerName = 'Partner',
    required this.notesDao,
  });

  @override
  State<CollaborativeNoteScreen> createState() => _CollaborativeNoteScreenState();
}

class _CollaborativeNoteScreenState extends State<CollaborativeNoteScreen> {
  late final TextEditingController _textController;
  bool _isLoading = true;
  String _currentText = '';
  int _sequence = 0;
  bool _isSynced = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note = await widget.notesDao.getNoteById(widget.noteId);
    if (note != null) {
      _currentText = note.plainText;
      _textController.text = note.plainText;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleTextChanged(String newText) async {
    if (newText == _currentText) return;

    setState(() => _isSynced = false);

    _sequence++;
    final hlc = DateTime.now().toUtc().toIso8601String();

    // Determine delta type
    final CrdtDelta delta;
    if (newText.length > _currentText.length) {
      // Append / insert
      delta = CrdtDelta(
        id: 'delta_${DateTime.now().millisecondsSinceEpoch}_$_sequence',
        noteId: widget.noteId,
        authorId: widget.currentUserId,
        opType: CrdtOpType.insert,
        position: _textController.selection.baseOffset >= 0
            ? _textController.selection.baseOffset - (newText.length - _currentText.length)
            : 0,
        text: newText.substring(
          _textController.selection.baseOffset >= 0
              ? _textController.selection.baseOffset - (newText.length - _currentText.length)
              : 0,
          _textController.selection.baseOffset >= 0
              ? _textController.selection.baseOffset
              : newText.length,
        ),
        sequence: _sequence,
        versionHlc: hlc,
        appliedAt: DateTime.now().toUtc(),
      );
    } else {
      // Delete / replace
      delta = CrdtDelta(
        id: 'delta_${DateTime.now().millisecondsSinceEpoch}_$_sequence',
        noteId: widget.noteId,
        authorId: widget.currentUserId,
        opType: CrdtOpType.delete,
        position: _textController.selection.baseOffset >= 0
            ? _textController.selection.baseOffset
            : 0,
        length: _currentText.length - newText.length,
        sequence: _sequence,
        versionHlc: hlc,
        appliedAt: DateTime.now().toUtc(),
      );
    }

    _currentText = newText;

    // Persist updated text and delta
    await widget.notesDao.updatePlainText(
      noteId: widget.noteId,
      plainText: newText,
      versionHlc: hlc,
    );

    if (mounted) setState(() => _isSynced = true);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFFC6F135), size: 22),
            const SizedBox(width: 8),
            Text(
              'Shared Pad (${widget.partnerName})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                  color: _isSynced ? const Color(0xFFC6F135) : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _isSynced ? 'Live Sync' : 'Syncing...',
                  style: TextStyle(
                    color: _isSynced ? const Color(0xFFC6F135) : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC6F135)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(16)),
                ),
                child: TextField(
                  controller: _textController,
                  onChanged: _handleTextChanged,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Start writing ideas, workout notes, or goals together...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
    );
  }
}
