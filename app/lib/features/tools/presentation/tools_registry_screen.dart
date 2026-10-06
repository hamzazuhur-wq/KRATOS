// Wave 8: Tools Registry screen.
// Liquid Glass / Acid Lime — KRATOS design system.
// ADR-004: Tools are reusable inventory items; not XP owners.

import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: KratosSectionHeader(
          eyebrow: 'INVENTORY // ASSETS',
          title: 'Tools Registry',
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'RESOURCES',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime),
            onPressed: () {
              // TODO(Wave 12 UX): create tool sheet
            },
            tooltip: 'New Tool',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
        backgroundColor: isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime,
        foregroundColor: isDark ? Colors.black : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white38 : KratosTheme.lightTextSecondary,
          fontSize: 10,
          letterSpacing: 2.0,
          fontWeight: FontWeight.bold,
        ),
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

  Color _typeColor(bool isDark) {
    final color = ToolsRegistryScreen._typeColors[type] ?? (isDark ? Colors.white : Colors.black);
    // Darken slightly for light mode if it's the light yellow to maintain contrast
    if (!isDark && type == 'reference') {
      return KratosTheme.lightAcidLime;
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _typeColor(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.interactive,
        interactive: true,
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.build_circle, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: typeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _LinkCount(
                                icon: Icons.psychology,
                                count: linkedSkills,
                                label: 'skills'),
                            const SizedBox(width: 16),
                            _LinkCount(
                                icon: Icons.task_alt,
                                count: linkedTasks,
                                label: 'tasks'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? const Color(0xFF686D65) : KratosTheme.lightTextMuted,
                    size: 18,
                  ),
                ],
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextMuted;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: color, 
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
