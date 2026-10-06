import 'package:flutter/material.dart';
import '../../app/kratos_theme.dart';
import '../../app/kratos_visuals.dart';

class Wave07StorybookScreen extends StatelessWidget {
  const Wave07StorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Wave 07: Skills & Tools Storybook')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('DARK MODE - SKILL CARD', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.darkTheme,
            child: _buildSkillCard(true),
          ),
          const SizedBox(height: 24),
          const Text('LIGHT MODE - SKILL CARD', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.lightTheme,
            child: _buildSkillCard(false),
          ),
          const SizedBox(height: 40),
          const Text('DARK MODE - TOOL CARD', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.darkTheme,
            child: _buildToolCard(true),
          ),
          const SizedBox(height: 24),
          const Text('LIGHT MODE - TOOL CARD', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.lightTheme,
            child: _buildToolCard(false),
          ),
          const SizedBox(height: 40),
          const Text('EMPTY STATE - DARK', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.darkTheme,
            child: const KratosEmptyState(
              icon: Icons.psychology_outlined,
              title: 'NO SKILLS',
              subtitle: 'Adjust filters or add a new skill capability to track progression.',
            ),
          ),
          const SizedBox(height: 24),
          const Text('EMPTY STATE - LIGHT', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Theme(
            data: KratosTheme.lightTheme,
            child: const KratosEmptyState(
              icon: Icons.psychology_outlined,
              title: 'NO SKILLS',
              subtitle: 'Adjust filters or add a new skill capability to track progression.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(bool isDark) {
    final color = const Color(0xFFC6F135);
    return KratosGlassCard(
      variant: KratosSurfaceVariant.interactive,
      interactive: true,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .3)),
              ),
              child: Text(
                'V',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
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
                          'Advanced Flutter',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'MASTER',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'DEVELOPMENT',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFF686D65),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Build high-performance UIs',
                    style: TextStyle(
                      color: Color(0xFF979C92),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(bool isDark) {
    final typeColor = const Color(0xFF7B68EE);
    return KratosGlassCard(
      variant: KratosSurfaceVariant.interactive,
      interactive: true,
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
                          'VS Code',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Primary code editor',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
