// Wave 8: Categories management screen.
// Liquid Glass / Acid Lime aesthetic — consistent with KRATOS UI system.
// ADR-003: SCD Type 2 versioning is visible to the user as "rule history".

import 'package:flutter/material.dart';

/// Placeholder screen for Category management.
///
/// Full implementation will use Riverpod providers backed by [CategoriesDao].
/// Shows the category list, baseXp, and action modifiers.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CATEGORIES',
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
              // TODO(Wave 8 UX): navigate to CreateCategorySheet
            },
            tooltip: 'New Category',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SeedCategoryCard(
            name: 'Health',
            icon: Icons.favorite,
            baseXp: 100,
            actions: [
              ('Morning workout', 0.20),
              ('Evening stretch', 0.10),
            ],
          ),
          SizedBox(height: 12),
          _SeedCategoryCard(
            name: 'Career',
            icon: Icons.work,
            baseXp: 120,
            actions: [
              ('Deep focus block', 0.25),
              ('Code review', 0.15),
            ],
          ),
          SizedBox(height: 12),
          _SeedCategoryCard(
            name: 'Learning',
            icon: Icons.school,
            baseXp: 80,
            actions: [
              ('Read documentation', 0.10),
              ('Complete chapter', 0.20),
            ],
          ),
          SizedBox(height: 12),
          _SeedCategoryCard(
            name: 'Relationships',
            icon: Icons.people,
            baseXp: 90,
            actions: [
              ('Quality time', 0.15),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO(Wave 8 UX): open create category bottom sheet
        },
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.category),
        label: const Text(
          'New Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SeedCategoryCard — Liquid Glass card for a single category
// ---------------------------------------------------------------------------

class _SeedCategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final int baseXp;
  final List<(String, double)> actions;

  const _SeedCategoryCard({
    required this.name,
    required this.icon,
    required this.baseXp,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFC6F135), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _XpBadge(baseXp: baseXp),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'ACTIONS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFC6F135), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.$1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${(a.$2 * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFFC6F135),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final int baseXp;
  const _XpBadge({required this.baseXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC6F135).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6F135).withValues(alpha: 0.4)),
      ),
      child: Text(
        '$baseXp XP',
        style: const TextStyle(
          color: Color(0xFFC6F135),
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
