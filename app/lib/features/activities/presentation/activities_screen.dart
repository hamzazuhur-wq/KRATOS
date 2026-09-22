// Wave 9: Activities list screen — Liquid Glass / Acid Lime.

import 'package:flutter/material.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ACTIVITIES',
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
            onPressed: () {},
            tooltip: 'New Activity',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ActivityTile(
            name: 'Morning Run',
            icon: '🏃',
            xpMode: 'per-minute',
            xpValue: 3,
            lifeArea: 'Health',
            totalSessions: 22,
          ),
          SizedBox(height: 10),
          _ActivityTile(
            name: 'Deep Work Block',
            icon: '💻',
            xpMode: 'per-minute',
            xpValue: 5,
            lifeArea: 'Career',
            totalSessions: 45,
          ),
          SizedBox(height: 10),
          _ActivityTile(
            name: 'Book Chapter',
            icon: '📖',
            xpMode: 'flat',
            xpValue: 80,
            lifeArea: 'Learning',
            totalSessions: 13,
          ),
          SizedBox(height: 10),
          _ActivityTile(
            name: 'Family Dinner',
            icon: '🍽️',
            xpMode: 'flat',
            xpValue: 50,
            lifeArea: 'Relationships',
            totalSessions: 30,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.local_activity),
        label: const Text(
          'New Activity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String name;
  final String icon;
  final String xpMode;
  final int xpValue;
  final String lifeArea;
  final int totalSessions;

  const _ActivityTile({
    required this.name,
    required this.icon,
    required this.xpMode,
    required this.xpValue,
    required this.lifeArea,
    required this.totalSessions,
  });

  @override
  Widget build(BuildContext context) {
    final xpLabel = xpMode == 'per-minute' ? '$xpValue XP/min' : '$xpValue XP flat';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFC6F135).withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                lifeArea,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.repeat, color: Colors.white24, size: 12),
              const SizedBox(width: 3),
              Text(
                '$totalSessions sessions',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFC6F135).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFC6F135).withValues(alpha: 0.35)),
          ),
          child: Text(
            xpLabel,
            style: const TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        onTap: () {
          // TODO(Wave 9 UX): navigate to session timer with this activity
        },
      ),
    );
  }
}
