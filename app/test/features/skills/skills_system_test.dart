import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/errors.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/domain/timestamps.dart';
import 'package:kratos_app/features/skills/domain/skill_models.dart';
import 'package:kratos_app/features/skills/data/skills_repository.dart';
import 'package:kratos_app/features/skills/presentation/skills_registry_screen.dart';

void main() {
  test('mastery is independent and limited to five configured levels', () {
    final now = Iso8601Timestamp.now();
    final skill = SkillEntity(
      id: Id.uuidV7(),
      ownerId: Id.uuidV7(),
      name: 'Design',
      xpTotal: 0,
      level: 1,
      masteryLevel: 3,
      versionHlc: Hlc.now(Id.uuidV7()),
      createdAt: now,
      updatedAt: now,
    );
    expect(skill.mastery, SkillMastery.advanced);
    expect(() => SkillMastery.fromValue(6), throwsA(isA<ValidationError>()));
  });

  test(
    'local Skills schema persists groups, mastery, and Life Area links',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now().toUtc();
      await db
          .into(db.skillGroups)
          .insert(
            SkillGroupsCompanion.insert(
              id: 'group-1',
              ownerId: 'owner-1',
              name: 'Creative',
              versionHlc: '0:0:1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.skills)
          .insert(
            SkillsCompanion.insert(
              id: 'skill-1',
              ownerId: 'owner-1',
              name: 'Typography',
              groupId: const Value('group-1'),
              xpTotal: 0,
              level: 1,
              masteryLevel: const Value(3),
              icon: const Value(null),
              versionHlc: '0:0:1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.skillLifeAreaLinks)
          .insert(
            SkillLifeAreaLinksCompanion.insert(
              ownerId: 'owner-1',
              skillId: 'skill-1',
              lifeAreaId: 'life-1',
              versionHlc: '0:0:2',
              createdAt: now,
            ),
          );
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'project-1',
              ownerId: 'owner-1',
              title: 'Brand system',
              status: 'active',
              memberIds: '[]',
              versionHlc: '0:0:3',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.attachmentLinksDao.upsert(
        AttachmentLinksCompanion.insert(
          id: 'skill-project-link-1',
          attachmentId: 'skill-1',
          attachmentKind: 'skill',
          entityId: 'project-1',
          entityKind: 'project',
          versionHlc: '0:0:4',
          createdAt: now,
        ),
      );

      final skills = await db.skillsDao.listSkills(
        'owner-1',
        groupId: 'group-1',
        masteryLevel: 3,
      );
      expect(skills.single.name, 'Typography');
      expect(
        (await db.skillsDao.skillsForLifeArea('owner-1', 'life-1')).single.id,
        'skill-1',
      );
      expect((await db.skillsDao.listSkills('other-owner')).isEmpty, isTrue);
      final projectLinks = await db.attachmentLinksDao.forEntity(
        'project-1',
        'project',
      );
      expect(projectLinks.single.attachmentId, 'skill-1');
    },
  );

  test('Skills repository persists mutations and emits outbox records', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ownerId = Id.uuidV7().value;
    final repository = DriftSkillsRepository(db);

    await repository.createGroup(ownerId: ownerId, name: 'Creative');
    final group = (await repository.listGroups(ownerId)).single;
    await repository.createSkill(
      ownerId: ownerId,
      name: 'Typography',
      groupId: group.id,
      masteryLevel: 3,
    );
    final skill = (await repository.listSkills(ownerId)).single;
    await repository.attachSkillToLifeArea(
      ownerId: ownerId,
      skillId: skill.id,
      lifeAreaId: 'life-area-1',
    );

    expect(skill.masteryLevel, 3);
    final outbox = await db.select(db.syncOutbox).get();
    expect(
      outbox.map((item) => item.entity),
      containsAll(<String>['skill_groups', 'skills', 'skill_life_area_links']),
    );
  });

  testWidgets('Skills dashboard creates a real persisted Skill', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ownerId = Id.uuidV7().value;
    await tester.pumpWidget(
      MaterialApp(
        home: SkillsRegistryScreen(database: db, ownerId: ownerId),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Typography');
    await tester.tap(find.text('CREATE SKILL'));
    await tester.pumpAndSettle();
    expect(find.text('Typography'), findsOneWidget);
    expect((await db.skillsDao.listSkills(ownerId)).single.name, 'Typography');
  });
}
