// Wave 8: Tools Registry screen.
// Liquid Glass / Acid Lime — KRATOS design system.
// ADR-004: Tools are reusable inventory items; not XP owners.

import 'package:flutter/material.dart';

/// Tools Registry screen — placeholder for Wave 8 UX.
///
/// Full implementation will use Riverpod [ToolsNotifier] backed by [ToolsDao].
/// Tools are reusable: they can be linked to both Skills and Tasks.
class ToolsRegistryScreen extends StatelessWidget {
  const ToolsRegistryScreen({super.key});

  // Tool type color map
  static const _typeColors = <String, Color>{
    'software': Color(0xFF7B68EE),
    'hardware': Color(0xFFFF9500),
    'methodology': Color(0xFF00BCD4),
    'reference': Color(0xFFC6F135),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TOOLS',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFC6F135)),
            onPressed: () {
              // TODO(Wave 12 UX): create tool sheet
            },
            tooltip: 'New Tool',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader('SOFTWARE'),
          SizedBox(height: 8),
          _ToolTile(
            name: 'VS Code',
            type: 'software',
            description: 'Primary code editor',
            linkedSkills: 2,
            linkedTasks: 14,
          ),
          _ToolTile(
            name: 'Figma',
            type: 'software',
            description: 'UI/UX design tool',
            linkedSkills: 1,
            linkedTasks: 6,
          ),
          SizedBox(height: 16),
          _SectionHeader('METHODOLOGY'),
          SizedBox(height: 8),
          _ToolTile(
            name: 'Pomodoro Timer',
            type: 'methodology',
            description: 'Focus technique — 25 min blocks',
            linkedSkills: 0,
            linkedTasks: 22,
          ),
          _ToolTile(
            name: 'Zettelkasten',
            type: 'methodology',
            description: 'Note-linking system',
            linkedSkills: 1,
            linkedTasks: 5,
          ),
          SizedBox(height: 16),
          _SectionHeader('REFERENCE'),
          SizedBox(height: 8),
          _ToolTile(
            name: 'Flutter Docs',
            type: 'reference',
            description: 'Official Flutter documentation',
            linkedSkills: 1,
            linkedTasks: 8,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO(Wave 12): create tool flow
        },
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.build),
        label: const Text(
          'New Tool',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        letterSpacing: 2.0,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String name;
  final String type;
  final String description;
  final int linkedSkills;
  final int linkedTasks;

  const _ToolTile({
    required this.name,
    required this.type,
    required this.description,
    required this.linkedSkills,
    required this.linkedTasks,
  });

  Color _typeColor() =>
      ToolsRegistryScreen._typeColors[type] ?? const Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: typeColor.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.build_circle, color: typeColor, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _LinkCount(
                      icon: Icons.psychology,
                      count: linkedSkills,
                      label: 'skills'),
                  const SizedBox(width: 12),
                  _LinkCount(
                      icon: Icons.task_alt,
                      count: linkedTasks,
                      label: 'tasks'),
                ],
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type.toUpperCase(),
            style: TextStyle(
              color: typeColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _LinkCount(
      {required this.icon, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
