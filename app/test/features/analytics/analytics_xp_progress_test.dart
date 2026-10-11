import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/data/xp_progress_repository.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_xp_progress_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/xp_progress/kratos_crystal_emblem.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/xp_progress/xp_progress_gauge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Analytics XP Progress Card (Wave 06)', () {
    testWidgets('renders XP Progress title, description, and selectors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Progress'), findsOneWidget);
      expect(
        find.text('Your current XP progress within the selected Life Area.'),
        findsOneWidget,
      );
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets(
        'renders Level IV — Crystal and real progression metrics for specific area',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top-right level summary card & gauge header
      expect(find.text('LEVEL IV'), findsOneWidget);
      expect(find.text('Level IV — Crystal'), findsOneWidget);
      expect(find.text('Higher focus, greater consistency.'), findsOneWidget);

      // Gauge center text
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('2,450 / 3,000 XP'), findsOneWidget);
      expect(find.text('550 XP to next level'), findsOneWidget);

      // Key metrics row
      expect(find.text('Current XP'), findsOneWidget);
      expect(find.text('XP to Next Level'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('24,580 XP'), findsOneWidget);

      // Verify custom painter gauge and crystal emblem are present
      expect(find.byType(XpProgressGauge), findsOneWidget);
      expect(find.byType(KratosCrystalEmblem), findsWidgets);
    });

    testWidgets(
        'enforces Section 7 semantics: All Life Areas shows portfolio overview',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                startWithAllAreas: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Life Areas'), findsOneWidget);
      // Does NOT show a single area level or fake Level IV as the title
      expect(find.text('Level IV — Crystal'), findsNothing);
      expect(find.text('Portfolio Overview'), findsOneWidget);
      expect(find.text('86,420 XP'), findsOneWidget); // Historical total XP
      expect(find.text('Period XP'), findsOneWidget);
      expect(find.text('Across all Life Areas'), findsWidgets);
    });

    testWidgets('renders milestone progression ladder with correct locked states',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level Progression'), findsOneWidget);
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Diamond'), findsOneWidget);

      // Milestones render KratosCrystalEmblem for all nodes
      expect(find.byType(KratosCrystalEmblem), findsWidgets);
    });

    testWidgets('renders XP sources breakdown bars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Sources'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);

      expect(find.text('920 XP'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
    });

    testWidgets('handles empty domain (0 XP) gracefully without crashing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(isEmpty: true),
                initialLifeAreaId: 'la_empty',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 / 1,000 XP'), findsOneWidget);
      expect(find.text('1,000 XP to next level'), findsOneWidget);
      expect(find.text('0 XP'), findsWidgets);
    });

    testWidgets('renders cleanly in Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Progress'), findsOneWidget);
      expect(find.text('LEVEL IV'), findsOneWidget);
      expect(find.text('Level IV — Crystal'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
    });

    testWidgets('renders without overflow at 390x844 mobile viewport',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);


      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AnalyticsXpProgressCard(
                repository: MockXpProgressRepository(),
                initialLifeAreaId: 'la_prof',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final err = tester.takeException();
      expect(err, isNull);
    });
  });
}
