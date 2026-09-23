// Wave 11: AI Notes & Voice Memos hub — Liquid Glass / Acid Lime.
// OmniRoute: unified capture + notes + voice memo list.

import 'package:flutter/material.dart';

/// AI Notes hub — unified view for notes and voice memos.
///
/// Full implementation uses Riverpod [NotesNotifier] and [AudioNotifier]
/// backed by [NotesDao] and [AudioDao]. This is the faithful UI prototype.
class AiNotesScreen extends StatefulWidget {
  final List<({String title, String preview, bool isPinned, String timeAgo, String? aiTag})>? initialNotes;

  const AiNotesScreen({super.key, this.initialNotes});

  @override
  State<AiNotesScreen> createState() => _AiNotesScreenState();
}

class _AiNotesScreenState extends State<AiNotesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<({String title, String preview, bool isPinned, String timeAgo, String? aiTag})> _notes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notes = widget.initialNotes?.toList() ?? [
      (
        title: 'System Design Insights',
        preview: 'CAP theorem applies when we need to choose between consistency and availability.',
        isPinned: true,
        timeAgo: '2h ago',
        aiTag: 'AI Summary',
      ),
      (
        title: 'KRATOS Architecture Notes',
        preview: 'The XP ledger should be append-only with HLC timestamps for distributed ordering.',
        isPinned: false,
        timeAgo: 'Yesterday',
        aiTag: null,
      ),
      (
        title: 'Morning Reflection',
        preview: 'Today I need to focus on the sync engine and Supabase auth hardening.',
        isPinned: false,
        timeAgo: '3 days ago',
        aiTag: null,
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addNote(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _notes.insert(0, (
        title: text.split('\n').first,
        preview: text,
        isPinned: false,
        timeAgo: 'Just now',
        aiTag: 'Quick Capture',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI NOTES',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC6F135),
          labelColor: const Color(0xFFC6F135),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'NOTES'),
            Tab(text: 'VOICE MEMOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NotesTab(notes: _notes),
          const _VoiceMemosTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickCaptureSheet(context),
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        child: const Icon(Icons.add),
        tooltip: 'Quick Capture',
      ),
    );
  }

  void _showQuickCaptureSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _QuickCaptureSheet(onSave: _addNote),
    );
  }
}

// ---------------------------------------------------------------------------
// _NotesTab
// ---------------------------------------------------------------------------

class _NotesTab extends StatelessWidget {
  final List<({String title, String preview, bool isPinned, String timeAgo, String? aiTag})> notes;

  const _NotesTab({required this.notes});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = notes[index];
        return _NoteCard(
          title: n.title,
          preview: n.preview,
          isPinned: n.isPinned,
          timeAgo: n.timeAgo,
          aiTag: n.aiTag,
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String title;
  final String preview;
  final bool isPinned;
  final String timeAgo;
  final String? aiTag;

  const _NoteCard({
    required this.title,
    required this.preview,
    required this.isPinned,
    required this.timeAgo,
    this.aiTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPinned
            ? const Color(0xFFC6F135).withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPinned
              ? const Color(0xFFC6F135).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin,
                    color: Color(0xFFC6F135), size: 14),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (aiTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B68EE).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    aiTag!,
                    style: const TextStyle(
                      color: Color(0xFF7B68EE),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            timeAgo,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _VoiceMemosTab
// ---------------------------------------------------------------------------

class _VoiceMemosTab extends StatelessWidget {
  const _VoiceMemosTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _VoiceMemoTile(
          durationLabel: '2m 14s',
          capturedAt: 'Today, 08:32',
          transcriptionStatus: 'done',
          preview: 'Reminder to check the Drift migration on the progression...',
        ),
        SizedBox(height: 10),
        _VoiceMemoTile(
          durationLabel: '0m 45s',
          capturedAt: 'Yesterday, 22:14',
          transcriptionStatus: 'pending',
          preview: null,
        ),
        SizedBox(height: 10),
        _VoiceMemoTile(
          durationLabel: '5m 03s',
          capturedAt: 'Sep 20, 14:05',
          transcriptionStatus: 'done',
          preview: 'KRATOS should allow partial XP allocation across multiple life areas...',
        ),
      ],
    );
  }
}

class _VoiceMemoTile extends StatelessWidget {
  final String durationLabel;
  final String capturedAt;
  final String transcriptionStatus; // 'done' | 'pending' | 'failed'
  final String? preview;

  const _VoiceMemoTile({
    required this.durationLabel,
    required this.capturedAt,
    required this.transcriptionStatus,
    this.preview,
  });

  Color get _statusColor {
    switch (transcriptionStatus) {
      case 'done':
        return const Color(0xFF4CAF50);
      case 'failed':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC6F135).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.mic,
                color: Color(0xFFC6F135), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      durationLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: _statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      transcriptionStatus,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (preview != null)
                  Text(
                    preview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else
                  const Text(
                    'Transcription in progress...',
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 3),
                Text(
                  capturedAt,
                  style:
                      const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _QuickCaptureSheet — OmniRoute quick entry
// ---------------------------------------------------------------------------

class _QuickCaptureSheet extends StatefulWidget {
  final ValueChanged<String>? onSave;
  const _QuickCaptureSheet({this.onSave});

  @override
  State<_QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<_QuickCaptureSheet> {
  final _controller = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK CAPTURE',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Capture a thought, idea, or reminder...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Voice memo button
              GestureDetector(
                onTap: () => setState(() => _isRecording = !_isRecording),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecording
                          ? const Color(0xFFFF3B30)
                          : Colors.white24,
                    ),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording
                        ? const Color(0xFFFF3B30)
                        : Colors.white54,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  widget.onSave?.call(_controller.text);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC6F135),
                  foregroundColor: const Color(0xFF0D0D0D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
