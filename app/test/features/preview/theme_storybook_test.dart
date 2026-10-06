import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/app/kratos_visuals.dart';
import 'package:kratos_app/features/preview/wave04_goals_storybook_screen.dart';
import 'package:kratos_app/features/preview/wave06_activities_storybook_screen.dart';
import 'package:kratos_app/features/preview/wave11_notifications_storybook_screen.dart';

void main() {
  group('KRATOS Design System & Wave Previews (Dark & Light Mode)', () {
    testWidgets('renders all KratosGlassCard variants in Dark Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.normal,
                    child: Text('Normal Dark Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.elevated,
                    child: Text('Elevated Dark Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.active,
                    child: Text('Active Dark Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.interactive,
                    child: Text('Interactive Dark Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.disabled,
                    child: Text('Disabled Dark Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.selected,
                    child: Text('Selected Dark Glass'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal Dark Glass'), findsOneWidget);
      expect(find.text('Elevated Dark Glass'), findsOneWidget);
      expect(find.text('Active Dark Glass'), findsOneWidget);
      expect(find.text('Interactive Dark Glass'), findsOneWidget);
      expect(find.text('Disabled Dark Glass'), findsOneWidget);
      expect(find.text('Selected Dark Glass'), findsOneWidget);
    });

    testWidgets('renders all KratosGlassCard variants in Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.normal,
                    child: Text('Normal Light Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.elevated,
                    child: Text('Elevated Light Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.active,
                    child: Text('Active Light Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.interactive,
                    child: Text('Interactive Light Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.disabled,
                    child: Text('Disabled Light Glass'),
                  ),
                  const KratosGlassCard(
                    variant: KratosSurfaceVariant.selected,
                    child: Text('Selected Light Glass'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal Light Glass'), findsOneWidget);
      expect(find.text('Elevated Light Glass'), findsOneWidget);
      expect(find.text('Active Light Glass'), findsOneWidget);
      expect(find.text('Interactive Light Glass'), findsOneWidget);
      expect(find.text('Disabled Light Glass'), findsOneWidget);
      expect(find.text('Selected Light Glass'), findsOneWidget);
    });

    testWidgets('renders Wave04 Goals Storybook in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Wave04GoalsStorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 04'), findsOneWidget);
      expect(find.text('GOALS & NESTED FLOW STORYBOOK'), findsOneWidget);
      expect(find.text('Build Autonomous Operating System (KRATOS)'), findsOneWidget);
      expect(find.text('Implement Liquid Glass Visual Design System'), findsOneWidget);
      expect(find.text('Tune Web Animation Curves & 0 Overflow Constraints'), findsOneWidget);
      expect(find.text('Phase 1: Local SQLite & Drift Database Schema'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZERO INTENT DETECTED'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ZERO INTENT DETECTED'), findsOneWidget);
      expect(find.text('No Matching Goals Found'), findsOneWidget);
    });

    testWidgets('renders Wave04 Goals Storybook in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Wave04GoalsStorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 04'), findsOneWidget);
      expect(find.text('GOALS & NESTED FLOW STORYBOOK'), findsOneWidget);
      expect(find.text('Build Autonomous Operating System (KRATOS)'), findsOneWidget);
      expect(find.text('Implement Liquid Glass Visual Design System'), findsOneWidget);
      expect(find.text('Tune Web Animation Curves & 0 Overflow Constraints'), findsOneWidget);
      expect(find.text('Phase 1: Local SQLite & Drift Database Schema'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZERO INTENT DETECTED'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ZERO INTENT DETECTED'), findsOneWidget);
      expect(find.text('No Matching Goals Found'), findsOneWidget);
    });

    testWidgets('renders Wave06 Activities & Focus Storybook in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Wave06StorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 06'), findsOneWidget);
      expect(find.text('ACTIVITIES · FOCUS · SESSIONS SHOWCASE'), findsOneWidget);
      expect(find.text('High Intensity Resistance Training'), findsAtLeastNWidgets(1));
      expect(find.text('Systems Architecture & Rust Kernels'), findsOneWidget);
      expect(find.text('ACTIVE COMMAND: DEEP FOCUS'), findsOneWidget);
      expect(find.text('42:15'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('RECENT SESSIONS AUDIT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT SESSIONS AUDIT'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZERO RECURRENT SESSIONS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ZERO RECURRENT SESSIONS'), findsOneWidget);
      expect(find.text('No Activities Registered'), findsOneWidget);
    });

    testWidgets('renders Wave06 Activities & Focus Storybook in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Wave06StorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 06'), findsOneWidget);
      expect(find.text('ACTIVITIES · FOCUS · SESSIONS SHOWCASE'), findsOneWidget);
      expect(find.text('High Intensity Resistance Training'), findsAtLeastNWidgets(1));
      expect(find.text('Systems Architecture & Rust Kernels'), findsOneWidget);
      expect(find.text('ACTIVE COMMAND: DEEP FOCUS'), findsOneWidget);
      expect(find.text('42:15'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('RECENT SESSIONS AUDIT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT SESSIONS AUDIT'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZERO RECURRENT SESSIONS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ZERO RECURRENT SESSIONS'), findsOneWidget);
      expect(find.text('No Activities Registered'), findsOneWidget);
    });

    testWidgets('renders Wave11 Notifications & Inbox Storybook in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Wave11NotificationsStorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 11'), findsOneWidget);
      expect(find.text('NOTIFICATIONS + INBOX SHOWCASE'), findsOneWidget);
      expect(find.text('Enable Device System Alerts'), findsOneWidget);
      expect(find.text('OVERDUE'), findsAtLeastNWidgets(1));
      expect(find.text('DUE TODAY'), findsAtLeastNWidgets(1));
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('Task Overdue: Complete CRDT Integration Test Suite'), findsOneWidget);
      expect(find.text('Goal Target Ending Today: Liquid Glass Polish'), findsOneWidget);
      expect(find.text('Progression Threshold Achieved: Level 14'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('06 / ACTIVITY TIMELINE STREAM'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('LEVEL UP: REACHED LEVEL 14'), findsOneWidget);
      expect(find.text('+250 XP EARNED (FOCUS SESSION)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('07 / ZERO STATE / EMPTY NOTIFICATIONS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('All Clear'), findsOneWidget);
      expect(find.text('No pending alerts, overdue tasks, or stale items.'), findsOneWidget);
      expect(find.text('No Activity Recorded Yet'), findsOneWidget);
    });

    testWidgets('renders Wave11 Notifications & Inbox Storybook in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Wave11NotificationsStorybookScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAVE 11'), findsOneWidget);
      expect(find.text('NOTIFICATIONS + INBOX SHOWCASE'), findsOneWidget);
      expect(find.text('Enable Device System Alerts'), findsOneWidget);
      expect(find.text('OVERDUE'), findsAtLeastNWidgets(1));
      expect(find.text('DUE TODAY'), findsAtLeastNWidgets(1));
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('Task Overdue: Complete CRDT Integration Test Suite'), findsOneWidget);
      expect(find.text('Goal Target Ending Today: Liquid Glass Polish'), findsOneWidget);
      expect(find.text('Progression Threshold Achieved: Level 14'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('06 / ACTIVITY TIMELINE STREAM'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('LEVEL UP: REACHED LEVEL 14'), findsOneWidget);
      expect(find.text('+250 XP EARNED (FOCUS SESSION)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('07 / ZERO STATE / EMPTY NOTIFICATIONS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('All Clear'), findsOneWidget);
      expect(find.text('No pending alerts, overdue tasks, or stale items.'), findsOneWidget);
      expect(find.text('No Activity Recorded Yet'), findsOneWidget);
    });
  });
}
