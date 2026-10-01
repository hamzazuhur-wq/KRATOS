import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/projects/presentation/projects_screen.dart';

void main() {
  testWidgets('project create and edit persist through the real screen', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProjectsScreen(database: database, ownerId: 'owner-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Project').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Test Project');
    await tester.ensureVisible(find.text('CREATE PROJECT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE PROJECT'));
    await tester.pumpAndSettle();

    expect(find.text('TEST PROJECT'), findsWidgets);
    expect((await database.select(database.projects).get()).single.title,
        'Test Project');

    await tester.tap(find.byTooltip('Edit Project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Edited Project');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('EDITED PROJECT'), findsWidgets);
    expect((await database.select(database.projects).get()).single.title,
        'Edited Project');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
