// Wave 4: Placeholder Tasks screen.
// Full UX is in Wave 9 — this screen shows a simple task list as a stub.

import 'package:flutter/material.dart';

/// Placeholder screen shown in Wave 4.
/// Replaced with full UX in Wave 9.
class TasksPlaceholderScreen extends StatelessWidget {
  const TasksPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'TASKS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, color: Color(0xFFC6F135), size: 64),
            SizedBox(height: 24),
            Text(
              'Tasks — Wave 9',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Full task management UI coming in Wave 9.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: Colors.black,
        onPressed: () {
          // TODO(wave9): open task creation sheet
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Placeholder attachment picker widget.
/// Shown in Wave 4 — full implementation in Wave 13.
class AttachmentPickerPlaceholder extends StatelessWidget {
  final String entityId;
  final String entityKind;

  const AttachmentPickerPlaceholder({
    super.key,
    required this.entityId,
    required this.entityKind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ATTACHMENTS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AttachButton(
                icon: Icons.attach_file,
                label: 'File',
                onTap: () {
                  // TODO(wave13): open file picker
                },
              ),
              const SizedBox(width: 12),
              _AttachButton(
                icon: Icons.link,
                label: 'URL',
                onTap: () {
                  // TODO(wave13): open link input
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC6F135).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC6F135), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
