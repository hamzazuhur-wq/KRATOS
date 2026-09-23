// ignore_for_file: public_member_api_docs
// Wave 17: OnboardingService — Seeds initial LifeAreas, starter Goals, and initial Freeze Tokens.
// Invariant #3: Streaks and levels are per-LifeArea.
// ADR-005: Every LifeArea starts with 2 free streak freeze tokens.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';
import '../../../data/drift/ledger_tables.dart';
import '../../../domain/ids.dart';
import 'onboarding_models.dart';

class OnboardingService {
  final AppDatabase _db;

  OnboardingService(this._db);

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
  }) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      for (final template in OnboardingDefaults.templates) {
        if (!selectedAreaIds.contains(template.id)) continue;

        // 1. Insert Life Area
        await _db.into(_db.lifeAreas).insertOnConflictUpdate(
          LifeAreasCompanion(
            id: Value(template.id),
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

        // 2. Seed initial freeze tokens (ADR-005: 2 free tokens per LifeArea)
        await _db.into(_db.streakFreezeInventory).insertOnConflictUpdate(
          StreakFreezeInventoryCompanion(
            id: Value(Id.uuidV7().value),
            userId: Value(userId),
            lifeAreaId: Value(template.id),
            tokensAvailable: const Value(2),
            tokensUsed: const Value(0),
            updatedAt: Value(now),
          ),
        );
      }

      // 3. Insert initial root goal if specified
      if (initialGoalTitle != null && initialGoalTitle.trim().isNotEmpty) {
        final goalId = Id.uuidV7().value;
        final primaryAreaId = selectedAreaIds.isNotEmpty ? selectedAreaIds.first : null;

        await _db.into(_db.goals).insert(
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
      }
    });
  }
}
