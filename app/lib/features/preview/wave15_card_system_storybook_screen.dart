import 'package:flutter/material.dart';

import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';

class Wave15CardSystemStorybookScreen extends StatefulWidget {
  const Wave15CardSystemStorybookScreen({super.key});

  @override
  State<Wave15CardSystemStorybookScreen> createState() => _Wave15CardSystemStorybookScreenState();
}

class _Wave15CardSystemStorybookScreenState extends State<Wave15CardSystemStorybookScreen> {
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    final theme = _isDark ? KratosTheme.darkTheme : KratosTheme.lightTheme;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(child: KratosEnvironment()),
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Card Design System Preview'),
                    floating: true,
                    actions: [
                      IconButton(
                        icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
                        onPressed: () => setState(() => _isDark = !_isDark),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildVariant(
                          'Normal Variant',
                          'Standard calm translucent glass.',
                          KratosSurfaceVariant.normal,
                        ),
                        _buildVariant(
                          'Elevated Variant',
                          'Higher prominence with deeper shadow.',
                          KratosSurfaceVariant.elevated,
                        ),
                        _buildVariant(
                          'Active Variant',
                          'Active equipment surface with active stroke.',
                          KratosSurfaceVariant.active,
                        ),
                        _buildVariant(
                          'Interactive Variant',
                          'Interactive surface with hover highlight and physics.',
                          KratosSurfaceVariant.interactive,
                          interactive: true,
                        ),
                        _buildVariant(
                          'Selected Variant',
                          'Selected state with subtle tint.',
                          KratosSurfaceVariant.selected,
                        ),
                        _buildVariant(
                          'Disabled Variant',
                          'Dimmed, muted surface.',
                          KratosSurfaceVariant.disabled,
                        ),
                      ]),
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

  Widget _buildVariant(String title, String subtitle, KratosSurfaceVariant variant, {bool interactive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: KratosGlassCard(
        variant: variant,
        interactive: interactive,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: _isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.widgets_outlined),
                SizedBox(width: 8),
                Text('Sample Content'),
              ],
            )
          ],
        ),
      ),
    );
  }
}
