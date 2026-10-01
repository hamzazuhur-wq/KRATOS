// Wave 13: Evidence Hub screen — Liquid Glass / Acid Lime.
// Unified browser for files, URLs, and evidence items.

import 'package:flutter/material.dart';

class EvidenceHubScreen extends StatefulWidget {
  const EvidenceHubScreen({super.key});

  @override
  State<EvidenceHubScreen> createState() => _EvidenceHubScreenState();
}

class _EvidenceHubScreenState extends State<EvidenceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final List<({String title, String url, String dateAdded})> _links = [
    (title: 'Drift Documentation', url: 'https://drift.simonbinder.eu', dateAdded: 'Sep 21'),
    (title: 'Flutter Dev', url: 'https://flutter.dev', dateAdded: 'Sep 19'),
    (title: 'Supabase Docs', url: 'https://supabase.com/docs', dateAdded: 'Sep 10'),
  ];

  final List<({String kind, String payload, String capturedAt})> _evidence = [
    (kind: 'goal_completion', payload: 'Goal: Read 10 books — completed', capturedAt: 'Sep 22'),
    (kind: 'streak_milestone', payload: 'Streak: 30-day run streak reached', capturedAt: 'Sep 18'),
    (kind: 'skill_level_up', payload: 'Flutter Dev reached Level 8', capturedAt: 'Sep 15'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ADD LINK OR EVIDENCE', style: TextStyle(color: Color(0xFFC6F135), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Title or description',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'URL (optional for evidence)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final url = urlController.text.trim();
                    if (title.isNotEmpty) {
                      setState(() {
                        if (url.isNotEmpty) {
                          _links.insert(0, (title: title, url: url, dateAdded: 'Today'));
                        } else {
                          _evidence.insert(0, (kind: 'manual', payload: title, capturedAt: 'Today'));
                        }
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC6F135), foregroundColor: const Color(0xFF0D0D0D)),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'EVIDENCE HUB',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFC6F135),
          labelColor: const Color(0xFFC6F135),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
          tabs: const [
            Tab(text: 'FILES'),
            Tab(text: 'LINKS'),
            Tab(text: 'EVIDENCE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _FilesTab(),
          _LinksTab(links: _links),
          _EvidenceTab(evidence: _evidence),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        tooltip: 'Add Attachment',
        child: const Icon(Icons.attach_file),
      ),
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _FileTile(name: 'architecture_diagram.png', size: '2.4 MB', mime: 'image/png', dateAdded: 'Sep 22'),
        SizedBox(height: 8),
        _FileTile(name: 'kratos_spec_v2.pdf', size: '1.1 MB', mime: 'application/pdf', dateAdded: 'Sep 18'),
        SizedBox(height: 8),
        _FileTile(name: 'workout_log.csv', size: '44 KB', mime: 'text/csv', dateAdded: 'Sep 15'),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  final String name;
  final String size;
  final String mime;
  final String dateAdded;
  const _FileTile({required this.name, required this.size, required this.mime, required this.dateAdded});

  IconData get _icon {
    if (mime.startsWith('image')) return Icons.image;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        leading: Icon(_icon, color: const Color(0xFFC6F135), size: 24),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: Text('$size · $dateAdded', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
      ),
    );
  }
}

class _LinksTab extends StatelessWidget {
  final List<({String title, String url, String dateAdded})> links;
  const _LinksTab({required this.links});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: links.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final l = links[index];
        return _LinkTile(title: l.title, url: l.url, dateAdded: l.dateAdded);
      },
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String url;
  final String dateAdded;
  const _LinkTile({required this.title, required this.url, required this.dateAdded});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        leading: const Icon(Icons.link, color: Color(0xFF00BCD4), size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: Text(dateAdded, style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ),
    );
  }
}

class _EvidenceTab extends StatelessWidget {
  final List<({String kind, String payload, String capturedAt})> evidence;
  const _EvidenceTab({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: evidence.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final e = evidence[index];
        return _EvidenceTile(kind: e.kind, payload: e.payload, capturedAt: e.capturedAt);
      },
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final String kind;
  final String payload;
  final String capturedAt;
  const _EvidenceTile({required this.kind, required this.payload, required this.capturedAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFFC6F135), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payload, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 3),
                Text(capturedAt, style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
