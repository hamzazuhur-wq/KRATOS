// ignore_for_file: public_member_api_docs
// Wave 17: OnboardingService — Seeds initial LifeAreas, starter Goals, and initial Freeze Tokens.
// Invariant #3: Streaks and levels are per-LifeArea.
// ADR-005: Every LifeArea starts with 2 free streak freeze tokens.

import 'package:drift/drift.dart';

import 'dart:convert';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import 'onboarding_models.dart';

class OnboardingService {
  final AppDatabase _db;

  OnboardingService(this._db);

  Future<bool> isCompleted(String userId) async =>
      await (_db.select(
        _db.users,
      )..where((row) => row.id.equals(userId))).getSingleOrNull() !=
      null;

  /// Executes onboarding bootstrap transaction:
  /// 1. Inserts chosen Life Areas.
  /// 2. Seeds 2 streak freeze tokens per chosen Life Area.
  /// 3. Creates the user's initial root goal if provided.
  Future<void> completeOnboarding({
    required String userId,
    required Set<String> selectedAreaIds,
    String? initialGoalTitle,
    int initialGoalXp = 500,
    required String versionHlc,
    String? deviceId,
  }) async {
    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? Id.uuidV7().value;

    await _db.transaction(() async {
      final existingProfile = await (_db.select(
        _db.users,
      )..where((row) => row.id.equals(userId))).getSingleOrNull();
      if (existingProfile != null) return;

      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              deviceId: effectiveDeviceId,
              displayName: const Value(null),
              timezone: DateTime.now().timeZoneName,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final areaIds = <String, String>{};
      for (final template in OnboardingDefaults.templates) {
        if (!selectedAreaIds.contains(template.id)) continue;
        final areaId = Id.uuidV7().value;
        areaIds[template.id] = areaId;

        // 1. Insert Life Area
        await _db
            .into(_db.lifeAreas)
            .insertOnConflictUpdate(
              LifeAreasCompanion(
                id: Value(areaId),
                ownerId: Value(userId),
                name: Value(template.name),
                description: Value(template.description),
                color: Value(template.colorHex),
                icon: Value(template.icon),
                sortOrder: const Value(0),
                versionHlc: Value(versionHlc),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _enqueue(
          userId: userId,
          deviceId: effectiveDeviceId,
          entity: 'life_areas',
          entityId: areaId,
          hlc: versionHlc,
          payload: {
            'name': template.name,
            'description': template.description,
            'color': template.colorHex,
            'icon': template.icon,
            'sort_order': 0,
          },
        );

        // 2. Seed initial freeze tokens (ADR-005: 2 free tokens per LifeArea)
        await _db
            .into(_db.streakFreezeInventory)
            .insertOnConflictUpdate(
              StreakFreezeInventoryCompanion(
                id: Value(Id.uuidV7().value),
                userId: Value(userId),
                lifeAreaId: Value(areaId),
                tokensAvailable: const Value(2),
                tokensUsed: const Value(0),
                updatedAt: Value(now),
              ),
            );
      }

      // 3. Insert initial root goal if specified
      if (initialGoalTitle != null && initialGoalTitle.trim().isNotEmpty) {
        final goalId = Id.uuidV7().value;
        final primaryAreaId = selectedAreaIds.isNotEmpty
            ? areaIds[selectedAreaIds.first]
            : null;

        await _db
            .into(_db.goals)
            .insert(
              GoalsCompanion(
                id: Value(goalId),
                ownerId: Value(userId),
                rootId: Value(goalId),
                path: Value(goalId),
                depth: const Value(0),
                title: Value(initialGoalTitle.trim()),
                lifeAreaId: Value(primaryAreaId),
                status: const Value('active'),
                xpTarget: Value(initialGoalXp),
                progress: const Value(0.0),
                versionHlc: Value(versionHlc),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _enqueue(
          userId: userId,
          deviceId: effectiveDeviceId,
          entity: 'goals',
          entityId: goalId,
          hlc: versionHlc,
          payload: {
            'root_id': goalId,
            'path': goalId,
            'depth': 0,
            'title': initialGoalTitle.trim(),
            'life_area_id': primaryAreaId,
            'status': 'active',
            'xp_target': initialGoalXp,
            'progress': 0,
          },
        );
      }
    });
  }

  Future<void> bootstrapDevUser({
    required String userId,
    String displayName = 'Dev Operative',
  }) async {
    final now = DateTime.now().toUtc();
    final deviceId = Id.uuidV7().value;
    final versionHlc = Hlc.now(Id.uuidV7()).toString();

    await _db.progressionDao.ensureSeeded();

    await _db.transaction(() async {
      // 1. User row
      final existingProfile = await (_db.select(_db.users)..where((row) => row.id.equals(userId))).getSingleOrNull();
      if (existingProfile == null) {
        await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: userId,
            deviceId: deviceId,
            displayName: Value(displayName),
            timezone: DateTime.now().timeZoneName,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 2. Life Areas
      final healthAreaId = 'la_health_$userId';
      final careerAreaId = 'la_career_$userId';
      final mindsetAreaId = 'la_mindset_$userId';

      final defaultAreas = [
        (id: healthAreaId, name: 'Health & Vitality', desc: 'Physical fitness, nutrition, and deep sleep', color: '#4CAF50', icon: 'favorite'),
        (id: careerAreaId, name: 'Career & Mastery', desc: 'Engineering excellence and professional milestones', color: '#2196F3', icon: 'work'),
        (id: mindsetAreaId, name: 'Mindset & Focus', desc: 'Mental clarity, meditation, and daily reflection', color: '#9C27B0', icon: 'psychology'),
      ];

      for (final a in defaultAreas) {
        await _db.into(_db.lifeAreas).insertOnConflictUpdate(
          LifeAreasCompanion(
            id: Value(a.id),
            ownerId: Value(userId),
            name: Value(a.name),
            description: Value(a.desc),
            color: Value(a.color),
            icon: Value(a.icon),
            sortOrder: const Value(0),
            versionHlc: Value(versionHlc),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // 2 streak freeze tokens
        await _db.into(_db.streakFreezeInventory).insertOnConflictUpdate(
          StreakFreezeInventoryCompanion(
            id: Value(Id.uuidV7().value),
            userId: Value(userId),
            lifeAreaId: Value(a.id),
            tokensAvailable: const Value(2),
            tokensUsed: const Value(0),
            updatedAt: Value(now),
          ),
        );
      }

      // 3. Default Categories
      final defaultCategories = [
        (name: 'Milestone', type: 'goal', xp: 500, icon: '🎯'),
        (name: 'Habit Goal', type: 'goal', xp: 300, icon: '⚡'),
        (name: 'Deep Work', type: 'task', xp: 150, icon: '🧠'),
        (name: 'Quick Win', type: 'task', xp: 50, icon: '🚀'),
        (name: 'Practice', type: 'activity', xp: 100, icon: '🔁'),
        (name: 'Routine', type: 'activity', xp: 50, icon: '⏱️'),
        (name: 'Professional', type: 'life_area', xp: 0, icon: '💼'),
        (name: 'Personal', type: 'life_area', xp: 0, icon: '🌟'),
      ];

      for (final cat in defaultCategories) {
        final catId = Id.uuidV7().value;
        await _db.into(_db.categories).insert(
          CategoriesCompanion(
            id: Value(catId),
            ownerId: Value(userId),
            name: Value(cat.name),
            categoryType: Value(cat.type),
            icon: Value(cat.icon),
            baseXp: Value(cat.xp),
            isImmutable: const Value(false),
            sortOrder: const Value(0),
            versionHlc: Value(versionHlc),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      // 4. Starter Goal
      final starterGoalId = Id.uuidV7().value;
      await _db.into(_db.goals).insert(
        GoalsCompanion(
          id: Value(starterGoalId),
          ownerId: Value(userId),
          rootId: Value(starterGoalId),
          path: Value(starterGoalId),
          depth: const Value(0),
          title: const Value('Establish Daily Mastery Routine'),
          description: const Value('Daily focus sessions, deep work, and streak building'),
          lifeAreaId: Value(careerAreaId),
          status: const Value('active'),
          xpTarget: const Value(500),
          progress: const Value(0.0),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 5. Starter Task (Due today)
      final starterTaskId = Id.uuidV7().value;
      await _db.into(_db.tasks).insert(
        TasksCompanion(
          id: Value(starterTaskId),
          ownerId: Value(userId),
          title: const Value('Execute Deep Work Protocol'),
          lifeAreaId: Value(careerAreaId),
          primaryGoalId: Value(starterGoalId),
          status: const Value('active'),
          priority: const Value(1),
          sortOrder: const Value(0),
          xpReward: const Value(150),
          dueDate: Value(now),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 6. Starter Activity
      final starterActivityId = Id.uuidV7().value;
      await _db.into(_db.activities).insert(
        ActivitiesCompanion(
          id: Value(starterActivityId),
          ownerId: Value(userId),
          name: const Value('Daily Focus Protocol'),
          description: const Value('45-minute distraction-free focus sprint'),
          lifeAreaId: Value(careerAreaId),
          targetDurationMinutes: const Value(45),
          difficulty: const Value(5),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 7. Starter Project
      final starterProjectId = Id.uuidV7().value;
      await _db.into(_db.projects).insert(
        ProjectsCompanion(
          id: Value(starterProjectId),
          ownerId: Value(userId),
          goalId: Value(starterGoalId),
          lifeAreaId: Value(careerAreaId),
          title: const Value('KRATOS Core Engine'),
          description: const Value('Autonomous productivity and progression system architecture'),
          status: const Value('active'),
          difficulty: const Value(3),
          progress: const Value(0.0),
          memberIds: const Value('[]'),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 8. Starter Skill
      final starterSkillId = Id.uuidV7().value;
      await _db.into(_db.skills).insert(
        SkillsCompanion(
          id: Value(starterSkillId),
          ownerId: Value(userId),
          name: const Value('Systems Architecture'),
          description: const Value('Designing high-throughput offline-first distributed workflows'),
          xpTotal: const Value(350),
          level: const Value(2),
          masteryLevel: const Value(2),
          icon: const Value('terminal'),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 9. Starter Idea Space & Idea
      final starterSpaceId = Id.uuidV7().value;
      await _db.into(_db.ideaSpaces).insert(
        IdeaSpacesCompanion(
          id: Value(starterSpaceId),
          ownerId: Value(userId),
          name: const Value('System Innovations'),
          description: const Value('Architecture concepts and product engineering thoughts'),
          icon: const Value('lightbulb'),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final starterIdeaId = Id.uuidV7().value;
      await _db.into(_db.ideas).insert(
        IdeasCompanion(
          id: Value(starterIdeaId),
          ownerId: Value(userId),
          title: const Value('Autonomous Goal Tracking Architecture'),
          contentJson: const Value('[{"insert":"Automate progress metrics across daily activity logs.\\n"}]'),
          excerpt: const Value('Automate progress metrics across daily activity logs.'),
          isPinned: const Value(true),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.ideaSpaceLinks).insert(
        IdeaSpaceLinksCompanion(
          id: Value(Id.uuidV7().value),
          ideaId: Value(starterIdeaId),
          ideaSpaceId: Value(starterSpaceId),
          ownerId: Value(userId),
          versionHlc: Value(versionHlc),
          createdAt: Value(now),
        ),
      );
    });
  }

  Future<void> _enqueue({
    required String userId,
    required String deviceId,
    required String entity,
    required String entityId,
    required String hlc,
    required Map<String, Object?> payload,
  }) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: userId,
            op: 'upsert',
            entity: entity,
            entityId: entityId,
            payloadJson: jsonEncode(payload),
            hlc: hlc,
            deviceId: deviceId,
          ),
        );
  }
}
