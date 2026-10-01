// Wave 17: Unit tests for Onboarding models, defaults, and state transitions.

import 'package:test/test.dart';
import 'package:kratos_app/features/onboarding/domain/onboarding_models.dart';

void main() {
  group('Onboarding Defaults and Templates', () {
    test('contains core 4 curated life areas', () {
      expect(OnboardingDefaults.templates.length, equals(4));
      final ids = OnboardingDefaults.templates.map((t) => t.id).toSet();
      expect(ids, containsAll(['la_health', 'la_career', 'la_learning', 'la_relationships']));
    });

    test('each template has valid color hex and default activities', () {
      for (final template in OnboardingDefaults.templates) {
        expect(template.colorHex, startsWith('#'));
        expect(template.name.isNotEmpty, isTrue);
        expect(template.defaultActivities.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('OnboardingState mutations', () {
    test('default state has 500 initial XP target and is not completed', () {
      const state = OnboardingState(selectedAreaIds: {'la_health'});
      expect(state.initialGoalXp, equals(500));
      expect(state.isCompleted, isFalse);
    });

    test('copyWith updates fields correctly', () {
      const state = OnboardingState(selectedAreaIds: {'la_health'});
      final updated = state.copyWith(
        selectedAreaIds: {'la_health', 'la_career'},
        initialGoalTitle: 'Ship KRATOS v1.0',
        initialGoalXp: 1000,
        isCompleted: true,
      );

      expect(updated.selectedAreaIds.length, equals(2));
      expect(updated.initialGoalTitle, equals('Ship KRATOS v1.0'));
      expect(updated.initialGoalXp, equals(1000));
      expect(updated.isCompleted, isTrue);
    });
  });
}
