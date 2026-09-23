// ignore_for_file: public_member_api_docs
// Wave 17: Onboarding domain models & default template definitions.
// Seeds initial life areas, default categories, and initial freeze inventory.

class DefaultLifeAreaTemplate {
  final String id;
  final String name;
  final String description;
  final String colorHex;
  final String icon;
  final List<String> defaultActivities;

  const DefaultLifeAreaTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.colorHex,
    required this.icon,
    required this.defaultActivities,
  });
}

class OnboardingDefaults {
  static const List<DefaultLifeAreaTemplate> templates = [
    DefaultLifeAreaTemplate(
      id: 'la_health',
      name: 'Health & Vitality',
      description: 'Physical fitness, nutrition, sleep, and recovery.',
      colorHex: '#4CAF50',
      icon: 'favorite',
      defaultActivities: ['Morning Workout', '10k Steps', 'Meditation'],
    ),
    DefaultLifeAreaTemplate(
      id: 'la_career',
      name: 'Career & Craft',
      description: 'Professional excellence, engineering, and impact.',
      colorHex: '#7B68EE',
      icon: 'work',
      defaultActivities: ['Deep Focus Block', 'Code Review', 'Architecture Design'],
    ),
    DefaultLifeAreaTemplate(
      id: 'la_learning',
      name: 'Knowledge & Mastery',
      description: 'Continuous reading, skill acquisition, and research.',
      colorHex: '#00BCD4',
      icon: 'school',
      defaultActivities: ['Read 30 Mins', 'Technical Research', 'Language Practice'],
    ),
    DefaultLifeAreaTemplate(
      id: 'la_relationships',
      name: 'Relationships',
      description: 'Family, friends, community, and presence.',
      colorHex: '#FF9500',
      icon: 'people',
      defaultActivities: ['Quality Time', 'Call Family', 'Deep Conversation'],
    ),
  ];
}

class OnboardingState {
  final Set<String> selectedAreaIds;
  final String? initialGoalTitle;
  final int initialGoalXp;
  final bool isCompleted;

  const OnboardingState({
    required this.selectedAreaIds,
    this.initialGoalTitle,
    this.initialGoalXp = 500,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    Set<String>? selectedAreaIds,
    String? initialGoalTitle,
    int? initialGoalXp,
    bool? isCompleted,
  }) {
    return OnboardingState(
      selectedAreaIds: selectedAreaIds ?? this.selectedAreaIds,
      initialGoalTitle: initialGoalTitle ?? this.initialGoalTitle,
      initialGoalXp: initialGoalXp ?? this.initialGoalXp,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
