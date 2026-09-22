// Wave 9: Projects list screen — Liquid Glass / Acid Lime.
// Projects are goal-linked work containers with task aggregation.

import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PROJECTS',
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
            tooltip: 'New Project',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ProjectCard(
            title: 'KRATOS App v1.0',
            status: 'active',
            goalTitle: 'Ship MVP',
            taskCount: 18,
            completedTasks: 12,
            daysLeft: 14,
          ),
          SizedBox(height: 12),
          _ProjectCard(
            title: 'Fitness Baseline',
            status: 'active',
            goalTitle: 'Build healthy habits',
            taskCount: 7,
            completedTasks: 3,
            daysLeft: 30,
          ),
          SizedBox(height: 12),
          _ProjectCard(
            title: 'System Design Course',
            status: 'completed',
            goalTitle: 'Level up engineering',
            taskCount: 10,
            completedTasks: 10,
            daysLeft: 0,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFFC6F135),
        foregroundColor: const Color(0xFF0D0D0D),
        icon: const Icon(Icons.folder_special),
        label: const Text(
          'New Project',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String status;
  final String goalTitle;
  final int taskCount;
  final int completedTasks;
  final int daysLeft;

  const _ProjectCard({
    required this.title,
    required this.status,
    required this.goalTitle,
    required this.taskCount,
    required this.completedTasks,
    required this.daysLeft,
  });

  Color get _statusColor {
    switch (status) {
      case 'completed':
        return const Color(0xFFC6F135);
      case 'paused':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFF00BCD4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = taskCount > 0 ? completedTasks / taskCount : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              Text(
                goalTitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$completedTasks / $taskCount tasks',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              if (status != 'completed' && daysLeft > 0)
                Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    color: daysLeft <= 7
                        ? const Color(0xFFFF3B30)
                        : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              if (status == 'completed')
                const Text(
                  'Done ✓',
                  style: TextStyle(color: Color(0xFFC6F135), fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
