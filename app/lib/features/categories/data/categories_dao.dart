// ignore_for_file: public_member_api_docs
// Wave 8: Drift DAO for Categories, CategoryActions, and CategoryXpRuleVersions.
// ADR-003: Slowly Changing Dimensions (SCD Type 2) rule-versioning.
// Invariant #9: Category rule changes never rewrite historical XP.

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';
import '../../../domain/ids.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, CategoryActions, CategoryXpRuleVersions])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// Fetch all active (non-archived) categories for owner.
  Future<List<Category>> allCategories(String ownerId) => (select(db.categories)
        ..where((c) => c.ownerId.equals(ownerId) & c.archivedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  /// Fetch single category.
  Future<Category?> findById(String id) =>
      (select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Fetch active actions for category (effective_until IS NULL).
  Future<List<CategoryAction>> activeActionsForCategory(String categoryId) =>
      (select(db.categoryActions)
            ..where((a) =>
                a.categoryId.equals(categoryId) & a.effectiveUntil.isNull()))
          .get();

  /// Fetch latest rule version snapshot for a category.
  Future<CategoryXpRuleVersion?> activeRuleVersion(String categoryId) =>
      (select(db.categoryXpRuleVersions)
            ..where((r) =>
                r.categoryId.equals(categoryId) & r.effectiveUntil.isNull())
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Create new category with initial rule version (SCD Type 2).
  Future<void> createCategory({
    required CategoriesCompanion category,
    required List<CategoryActionsCompanion> actions,
  }) =>
      transaction(() async {
        await into(db.categories).insert(category);

        for (final action in actions) {
          await into(db.categoryActions).insert(action);
        }

        // Freeze initial rule version snapshot
        final snapshot = {
          'base_xp': category.baseXp.value,
          'actions': actions
              .map((a) => {
                    'action_name': a.actionName.value,
                    'modifier_percent': a.modifierPercent.value,
                  })
              .toList(),
        };

        await into(db.categoryXpRuleVersions).insert(CategoryXpRuleVersionsCompanion(
          id: Value(Id.uuidV7().value),
          categoryId: category.id,
          snapshot: Value(jsonEncode(snapshot)),
          effectiveFrom: Value(DateTime.now().toUtc()),
          createdAt: Value(DateTime.now().toUtc()),
        ));
      });

  /// Publish a new rule version (ADR-003):
  /// Closes previous version's effective_until and creates a new immutable version row.
  Future<String> publishNewRuleVersion({
    required String categoryId,
    required int newBaseXp,
    required List<CategoryActionsCompanion> newActions,
    required String versionHlc,
  }) =>
      transaction(() async {
        final now = DateTime.now().toUtc();

        // 1. Close active rule version
        await (update(db.categoryXpRuleVersions)
              ..where((r) =>
                  r.categoryId.equals(categoryId) & r.effectiveUntil.isNull()))
            .write(CategoryXpRuleVersionsCompanion(
          effectiveUntil: Value(now),
        ));

        // 2. Close active category actions
        await (update(db.categoryActions)
              ..where((a) =>
                  a.categoryId.equals(categoryId) & a.effectiveUntil.isNull()))
            .write(CategoryActionsCompanion(
          effectiveUntil: Value(now),
        ));

        // 3. Update category base_xp and hlc
        await (update(db.categories)..where((c) => c.id.equals(categoryId)))
            .write(CategoriesCompanion(
          baseXp: Value(newBaseXp),
          versionHlc: Value(versionHlc),
          updatedAt: Value(now),
        ));

        // 4. Insert new actions
        for (final action in newActions) {
          await into(db.categoryActions).insert(action);
        }

        // 5. Freeze new immutable rule version row
        final newVersionId = Id.uuidV7().value;
        final snapshot = {
          'base_xp': newBaseXp,
          'actions': newActions
              .map((a) => {
                    'action_name': a.actionName.value,
                    'modifier_percent': a.modifierPercent.value,
                  })
              .toList(),
        };

        await into(db.categoryXpRuleVersions).insert(CategoryXpRuleVersionsCompanion(
          id: Value(newVersionId),
          categoryId: Value(categoryId),
          snapshot: Value(jsonEncode(snapshot)),
          effectiveFrom: Value(now),
          createdAt: Value(now),
        ));

        return newVersionId;
      });
}
