import '../../../data/drift/app_database.dart';
import '../../xp/domain/completion_bonus_calculator.dart';

/// Roman numeral representation for Project Difficulty on a 10-level scale (Ⅰ–Ⅹ).
abstract class ProjectDifficulty {
  static const List<String> romanNumerals = [
    'Ⅰ',
    'Ⅱ',
    'Ⅲ',
    'Ⅳ',
    'Ⅴ',
    'Ⅵ',
    'Ⅶ',
    'Ⅷ',
    'Ⅸ',
    'Ⅹ',
  ];

  static String toRoman(int difficulty) {
    final clamped = difficulty.clamp(1, 10);
    return romanNumerals[clamped - 1];
  }

  static int fromRoman(String roman) {
    final index = romanNumerals.indexOf(roman.trim());
    return index != -1 ? index + 1 : 1;
  }
}

/// XP calculation engine integration for Project completion.
/// Maps Difficulty (Ⅰ–Ⅹ) to independent base XP and a completion bonus.
class ProjectDifficultyXpCalculator {
  const ProjectDifficultyXpCalculator._();

  /// Monotonic, audited base XP curve for Project Difficulty 1..10.
  static const Map<int, int> difficultyBaseXp = {
    1: 100,
    2: 200,
    3: 350,
    4: 500,
    5: 750,
    6: 1000,
    7: 1500,
    8: 2250,
    9: 3500,
    10: 5000,
  };

  /// Returns base XP for a given difficulty rating.
  static int baseXp(int difficulty) {
    final clamped = difficulty.clamp(1, 10);
    return difficultyBaseXp[clamped] ?? 100;
  }

  static int calculateCompletionBonus(int baseProjectXp) =>
      CompletionBonusCalculator.calculate(baseProjectXp);

  /// Calculates the Project base reward and its 30% completion bonus.
  static ProjectXpBreakdown calculateXp({required int difficulty}) {
    final base = baseXp(difficulty);
    final bonus = calculateCompletionBonus(base);
    return ProjectXpBreakdown(
      baseXp: base,
      bonusPoints: bonus,
      totalXp: base + bonus,
    );
  }
}

class ProjectXpBreakdown {
  final int baseXp;
  final int bonusPoints;
  final int totalXp;

  const ProjectXpBreakdown({
    required this.baseXp,
    required this.bonusPoints,
    required this.totalXp,
  });
}

/// Phase lifecycle state.
enum ProjectPhaseStatus {
  active,
  paused,
  completed;

  static ProjectPhaseStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'completed':
        return ProjectPhaseStatus.completed;
      case 'paused':
        return ProjectPhaseStatus.paused;
      case 'active':
      default:
        return ProjectPhaseStatus.active;
    }
  }

  String get label {
    switch (this) {
      case ProjectPhaseStatus.active:
        return 'Active';
      case ProjectPhaseStatus.paused:
        return 'Paused';
      case ProjectPhaseStatus.completed:
        return 'Completed';
    }
  }
}

/// Deterministic, real calculation of Roadmap and Project progress.
/// Chain: Task completion → Phase progress → Roadmap progress → Project progress.
class RoadmapProgressCalculator {
  const RoadmapProgressCalculator._();

  /// Calculates progress for a single Phase from its linked Tasks (0.0 to 100.0).
  static double computePhaseProgress({
    required List<Task> phaseTasks,
    required String phaseStatus,
  }) {
    if (phaseTasks.isEmpty) {
      return phaseStatus == 'completed' ? 100.0 : 0.0;
    }
    final completed = phaseTasks.where((t) => t.status == 'completed').length;
    final pct = (completed / phaseTasks.length) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Calculates total Roadmap / Project progress from all Phases (0.0 to 100.0).
  /// If no phases exist, falls back to direct project tasks or 0.0.
  static double computeProjectProgress({
    required List<ProjectPhase> phases,
    required Map<String, List<Task>> tasksByPhaseId,
    required List<Task> unphasedProjectTasks,
  }) {
    final activePhases = phases.where((p) => p.deletedAt == null).toList();
    if (activePhases.isNotEmpty) {
      var totalPhaseProgress = 0.0;
      for (final phase in activePhases) {
        final phaseTasks = tasksByPhaseId[phase.id] ?? const [];
        totalPhaseProgress += computePhaseProgress(
          phaseTasks: phaseTasks,
          phaseStatus: phase.status,
        );
      }
      return (totalPhaseProgress / activePhases.length).clamp(0.0, 100.0);
    }

    // Fallback: If no phases exist, compute from direct project tasks
    final allTasks = [
      ...unphasedProjectTasks,
      ...tasksByPhaseId.values.expand((l) => l),
    ].where((t) => t.deletedAt == null).toList();

    if (allTasks.isNotEmpty) {
      final completed = allTasks.where((t) => t.status == 'completed').length;
      return ((completed / allTasks.length) * 100.0).clamp(0.0, 100.0);
    }

    return 0.0;
  }
}

/// Rich composite aggregate for a Project workspace with all related entities.
class ProjectWithDetails {
  final Project project;
  final LifeArea? lifeArea;
  final Goal? goal;
  final Goal? subGoal;
  final String? levelName;
  final List<Skill> skills;
  final List<ProjectPhase> phases;
  final List<Task> tasks;
  final List<Activity> activities;
  final List<DriftIdea> ideas;
  final List<File> files;
  final List<Note> notes;
  final List<Link> links;
  final double progress;

  const ProjectWithDetails({
    required this.project,
    this.lifeArea,
    this.goal,
    this.subGoal,
    this.levelName,
    required this.skills,
    required this.phases,
    required this.tasks,
    required this.activities,
    this.ideas = const [],
    required this.files,
    required this.notes,
    required this.links,
    required this.progress,
  });

  int get taskCount => tasks.length;
  int get completedTaskCount =>
      tasks.where((t) => t.status == 'completed').length;
  int get activityCount => activities.length;
  int get ideaCount => ideas.length;
  int get fileCount => files.length;
  int get noteCount => notes.length;
  int get linkCount => links.length;
  int get skillCount => skills.length;
}

/// Target types for the dual-selector "Assign To" control.
enum ProjectAssignmentType {
  lifeArea,
  goal,
  subGoal,
  level;

  String get label {
    switch (this) {
      case ProjectAssignmentType.lifeArea:
        return 'Life Area';
      case ProjectAssignmentType.goal:
        return 'Goal';
      case ProjectAssignmentType.subGoal:
        return 'Sub-goal';
      case ProjectAssignmentType.level:
        return 'Level';
    }
  }
}

/// A selectable item in the second selector of "Assign To".
class ProjectAssignmentTarget {
  final String id;
  final String title;
  final String? subtitle;
  final String? colorHex;
  final ProjectAssignmentType type;

  const ProjectAssignmentTarget({
    required this.id,
    required this.title,
    this.subtitle,
    this.colorHex,
    required this.type,
  });
}
