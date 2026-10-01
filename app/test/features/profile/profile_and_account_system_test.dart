import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/app_shell.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/auth/data/mock_auth_service.dart';
import 'package:kratos_app/features/profile/data/profile_repository.dart';
import 'package:kratos_app/features/profile/presentation/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthService mockAuth;
  const testUserId = 'usr_kratos_prime';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockAuth = MockAuthService();

    final now = DateTime.now().toUtc();

    // 1. Seed user in SQLite
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: testUserId,
            deviceId: 'test-device-01',
            displayName: const drift.Value('Spartan Commander'),
            caption: const drift.Value('Conquer the impossible every day'),
            avatarUrl: const drift.Value('https://example.com/avatar.png'),
            email: const drift.Value('spartan@kratos.app'),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 2. Seed Life Areas & XP
    const areaId1 = 'area_discipline';
    const areaId2 = 'area_coding';

    await db.into(db.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: areaId1,
            ownerId: testUserId,
            name: 'Discipline & Body',
            description: const drift.Value('Physical and mental conditioning'),
            color: const drift.Value('#C6F135'),
            icon: const drift.Value('fitness_center'),
            sortOrder: 1,
            versionHlc: 'hlc_1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: areaId2,
            ownerId: testUserId,
            name: 'Code & Intellect',
            description: const drift.Value('Engineering and learning'),
            color: const drift.Value('#35C6F1'),
            icon: const drift.Value('code'),
            sortOrder: 2,
            versionHlc: 'hlc_2',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed XP entries (area 1 has 500 XP, area 2 has 1200 XP)
    const ledgerId1 = 'ledger_01';
    await db.into(db.xpLedger).insert(
          XpLedgerCompanion.insert(
            id: ledgerId1,
            ownerId: testUserId,
            idempotencyKey: 'idem_01',
            sourceType: 'task',
            sourceId: 'task_01',
            action: 'complete',
            points: 500,
            versionHlc: 'hlc_01',
            deviceId: 'dev_01',
            createdAt: drift.Value(now),
          ),
        );
    await db.into(db.xpAllocationLines).insert(
          XpAllocationLinesCompanion.insert(
            id: 'line_01',
            ledgerId: ledgerId1,
            lifeAreaId: areaId1,
            allocatedPoints: 500,
            percentage: 1.0,
            versionHlc: 'hlc_01',
            createdAt: drift.Value(now),
          ),
        );

    const ledgerId2 = 'ledger_02';
    await db.into(db.xpLedger).insert(
          XpLedgerCompanion.insert(
            id: ledgerId2,
            ownerId: testUserId,
            idempotencyKey: 'idem_02',
            sourceType: 'task',
            sourceId: 'task_02',
            action: 'complete',
            points: 1200,
            versionHlc: 'hlc_02',
            deviceId: 'dev_01',
            createdAt: drift.Value(now),
          ),
        );
    await db.into(db.xpAllocationLines).insert(
          XpAllocationLinesCompanion.insert(
            id: 'line_02',
            ledgerId: ledgerId2,
            lifeAreaId: areaId2,
            allocatedPoints: 1200,
            percentage: 1.0,
            versionHlc: 'hlc_02',
            createdAt: drift.Value(now),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget home) {
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: HeroMode(
          enabled: false,
          child: home,
        ),
      ),
    );
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration maxDuration = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(maxDuration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
  }

  group('ProfileRepository Integration Tests', () {
    test('watchProfile reads real user data, primary XP domain, and highest level', () async {
      final repo = ProfileRepository(
        database: db,
        authService: mockAuth,
      );

      final profile = await repo.watchProfile(testUserId).first;

      expect(profile.userId.value, equals(testUserId));
      expect(profile.displayName, equals('Spartan Commander'));
      expect(profile.caption, equals('Conquer the impossible every day'));
      expect(profile.avatarUrl, equals('https://example.com/avatar.png'));
      expect(profile.email, equals('spartan@kratos.app'));
      // Code & Intellect has 1200 XP (max), so it should be primary
      expect(profile.primaryXpDomain, equals('Code & Intellect'));
      expect(profile.totalXp, equals(1700));
      expect(profile.highestLevel, contains('Bronze'));
    });

    test('updateProfile updates SQLite table reactively', () async {
      final repo = ProfileRepository(
        database: db,
        authService: mockAuth,
      );

      await repo.updateProfile(
        userId: testUserId,
        displayName: 'Ghost of Sparta',
        caption: 'Master of War and Intellect',
        avatarUrl: 'https://example.com/new_avatar.png',
      );

      final updated = await repo.getProfile(testUserId);
      expect(updated.displayName, equals('Ghost of Sparta'));
      expect(updated.caption, equals('Master of War and Intellect'));
      expect(updated.avatarUrl, equals('https://example.com/new_avatar.png'));
    });

    test('uploadAvatar returns base64 data URI when offline and saves to profile', () async {
      final repo = ProfileRepository(
        database: db,
        authService: mockAuth,
      );

      final rawBytes = utf8.encode('kratos_avatar_data_bytes');
      final resultUri = await repo.uploadAvatar(
        userId: testUserId,
        bytes: rawBytes,
        fileExt: 'png',
      );

      expect(resultUri, startsWith('data:image/png;base64,'));
      final updated = await repo.getProfile(testUserId);
      expect(updated.avatarUrl, equals(resultUri));
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('ProfileScreen renders identity, progression metrics, and action tiles',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        buildTestApp(
          ProfileScreen(
            database: db,
            userId: testUserId,
            authService: mockAuth,
          ),
        ),
      );

      await pumpUntilFound(tester, find.text('Spartan Commander'));

      // Header Identity
      expect(find.text('Spartan Commander'), findsWidgets);
      expect(find.text('Conquer the impossible every day'), findsAtLeast(1));

      // Progression Metrics
      expect(find.text('Code & Intellect'), findsOneWidget);
      expect(find.text('PRIMARY XP DOMAIN'), findsOneWidget);
      expect(find.text('HIGHEST LEVEL'), findsOneWidget);

      // Account Info
      expect(find.text('spartan@kratos.app'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);
      expect(find.text(testUserId), findsOneWidget);

      // Actions
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Edit Profile Dialog opens and saves changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        buildTestApp(
          ProfileScreen(
            database: db,
            userId: testUserId,
            authService: mockAuth,
          ),
        ),
      );

      await pumpUntilFound(tester, find.text('Spartan Commander'));

      // Tap Edit camera button on Avatar
      await tester.tap(find.byIcon(Icons.camera_alt));
      await pumpUntilFound(tester, find.text('Edit Profile'));

      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter new name and caption
      final nameFields = find.byType(TextField);
      expect(nameFields, findsAtLeastNWidgets(2));

      await tester.enterText(nameFields.at(0), 'Warlord Kratos');
      await tester.enterText(nameFields.at(1), 'Strength and Wisdom');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Save button
      final saveBtn = find.widgetWithText(ElevatedButton, 'Save');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);

      await pumpUntilFound(tester, find.text('Profile updated successfully'));
      await tester.pump(const Duration(milliseconds: 400));

      // Dialog dismissed and UI shows updated name
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Warlord Kratos'), findsWidgets);
      expect(find.text('Strength and Wisdom'), findsOneWidget);
    });

    testWidgets('Change Password Dialog validates matching passwords', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        buildTestApp(
          ProfileScreen(
            database: db,
            userId: testUserId,
            authService: mockAuth,
          ),
        ),
      );

      await pumpUntilFound(tester, find.text('Change Password'));

      // Tap Change Password tile
      await tester.tap(find.text('Change Password'));
      await pumpUntilFound(tester, find.widgetWithText(ElevatedButton, 'Update'));

      expect(find.byType(AlertDialog), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Enter mismatched passwords
      await tester.enterText(textFields.at(0), 'Secret1234');
      await tester.enterText(textFields.at(1), 'Secret9999');
      await tester.pump(const Duration(milliseconds: 50));

      final updateBtn = find.widgetWithText(ElevatedButton, 'Update');
      await tester.tap(updateBtn);
      await pumpUntilFound(tester, find.text('Passwords do not match'));

      // Error banner is displayed
      expect(find.text('Passwords do not match'), findsOneWidget);

      // Enter matching passwords
      await tester.enterText(textFields.at(1), 'Secret1234');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(updateBtn);
      await pumpUntilFound(tester, find.text('Password changed successfully'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Logout Confirmation Dialog triggers onSignOut callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      bool signedOut = false;

      await tester.pumpWidget(
        buildTestApp(
          ProfileScreen(
            database: db,
            userId: testUserId,
            authService: mockAuth,
            onSignOut: () {
              signedOut = true;
            },
          ),
        ),
      );

      await pumpUntilFound(tester, find.text('Sign Out'));

      // Tap Sign Out tile
      await tester.tap(find.text('Sign Out'));
      await pumpUntilFound(tester, find.text('Are you sure you want to sign out of KRATOS? Your local data will remain securely saved.'));

      expect(
        find.text('Are you sure you want to sign out of KRATOS? Your local data will remain securely saved.'),
        findsOneWidget,
      );

      // Tap confirm Sign Out
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(signedOut, isTrue);
    });
  });

  group('AppShell Sidebar Profile Header Tests', () {
    testWidgets('AppShell sidebar displays profile header and navigates to ProfileScreen on tap',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        buildTestApp(
          AppShell(
            database: db,
            userId: testUserId,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Open drawer using app bar menu button
      final menuButton = find.byIcon(Icons.menu);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Profile header in drawer is visible
      expect(find.text('Spartan Commander'), findsAtLeast(1));
      expect(find.text('Conquer the impossible every day'), findsAtLeast(1));

      // Tap profile header in drawer to navigate to ProfileScreen
      await tester.tap(find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Spartan Commander'),
      ).first);
      await tester.pumpAndSettle();

      // ProfileScreen is now opened
      expect(find.text('PROFILE & ACCOUNT'), findsOneWidget);
      expect(find.text('PRIMARY XP DOMAIN'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
