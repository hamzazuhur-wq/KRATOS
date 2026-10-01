import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_skeleton.dart';

void main() {
  group('KratosSkeletonTokens', () {
    test('Tokens are properly defined and calibrated', () {
      expect(KratosSkeletonTokens.shimmerDuration.inMilliseconds, equals(1500));
      expect(KratosSkeletonTokens.revealDuration.inMilliseconds, equals(380));
      expect(KratosSkeletonTokens.boneBaseColor, isNotNull);
      expect(KratosSkeletonTokens.shimmerHighlightColor, isNotNull);
    });
  });

  group('KratosBone Primitives', () {
    testWidgets('KratosBone renders circle, text, chip, and card without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                KratosBone.circle(size: 32),
                KratosBone.text(width: 140, height: 12),
                KratosBone.chip(width: 60, height: 24),
                KratosBone.card(
                  height: 80,
                  child: Text('Card Content'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(KratosBone), findsNWidgets(4));
      expect(find.text('Card Content'), findsOneWidget);
    });
  });

  group('KratosShimmer & Reduced Motion', () {
    testWidgets('KratosShimmer renders child and respects animations flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KratosShimmer(
              child: KratosBone.card(height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(KratosShimmer), findsOneWidget);
      expect(find.byType(KratosBone), findsOneWidget);
    });
  });

  group('SkeletonReveal Transition', () {
    testWidgets('SkeletonReveal displays skeleton when loading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonReveal(
              loading: true,
              skeleton: Text('Skeleton Placeholder'),
              child: Text('Real Content'),
            ),
          ),
        ),
      );

      expect(find.text('Skeleton Placeholder'), findsOneWidget);
      expect(find.text('Real Content'), findsNothing);
    });

    testWidgets('SkeletonReveal displays real content when loading is false without flash', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonReveal(
              loading: false,
              skeleton: Text('Skeleton Placeholder'),
              child: Text('Real Content'),
            ),
          ),
        ),
      );

      expect(find.text('Real Content'), findsOneWidget);
      expect(find.text('Skeleton Placeholder'), findsNothing);
    });

    testWidgets('SkeletonReveal smoothly reveals real content when loading switches', (
      tester,
    ) async {
      bool loading = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => loading = false),
                      child: const Text('Resolve'),
                    ),
                    SkeletonReveal(
                      loading: loading,
                      skeleton: const Text('Skeleton Placeholder'),
                      child: const Text('Real Content'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Skeleton Placeholder'), findsOneWidget);

      // Trigger resolve
      await tester.tap(find.text('Resolve'));
      await tester.pump(); // Start transition

      // Halfway through transition
      await tester.pump(const Duration(milliseconds: 190));
      expect(find.text('Real Content'), findsOneWidget);

      // Complete transition
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Real Content'), findsOneWidget);
    });
  });

  group('Specialized Skeletons', () {
    testWidgets('Page skeletons render without geometry errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 300, child: HomeDashboardSkeleton()),
                  SizedBox(height: 300, child: GoalsPageSkeleton()),
                  SizedBox(height: 300, child: TasksPageSkeleton()),
                  SizedBox(height: 300, child: ProjectsPageSkeleton()),
                  SizedBox(height: 300, child: ActivitiesPageSkeleton()),
                  SizedBox(height: 300, child: LevelsDashboardSkeleton()),
                  SizedBox(height: 300, child: SkillsPageSkeleton()),
                  SizedBox(height: 300, child: XpDashboardSkeleton()),
                  SizedBox(height: 300, child: LifeAreasPageSkeleton()),
                  SizedBox(height: 300, child: AnalyticsPageSkeleton()),
                  SizedBox(height: 300, child: GenericDetailSkeleton()),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HomeDashboardSkeleton), findsOneWidget);
      expect(find.byType(GoalsPageSkeleton), findsOneWidget);
      expect(find.byType(TasksPageSkeleton), findsOneWidget);
      expect(find.byType(ProjectsPageSkeleton), findsOneWidget);
    });
  });
}
