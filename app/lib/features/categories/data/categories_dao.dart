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

  /// Ensure default categories exist for the owner across all 4 category types.
  /// Seeds initial SCD Type 2 rule versions for each category (Invariant #9).
  Future<void> ensureSeeded(String ownerId) async {
    final existing = await (select(db.categories)
          ..where((c) => c.ownerId.equals(ownerId))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final hlc = Id.uuidV7().value;

    final defaults = [
      (name: 'Milestone', type: 'goal', xp: 500, icon: '🎯', desc: 'Major long-term milestones and achievements'),
      (name: 'Habit Goal', type: 'goal', xp: 300, icon: '⚡', desc: 'Recurring behavioral targets and habit tracking'),
      (name: 'Deep Work', type: 'task', xp: 150, icon: '🧠', desc: 'High-focus, cognitively demanding task blocks'),
      (name: 'Quick Win', type: 'task', xp: 50, icon: '🚀', desc: 'Short administrative or quick operational tasks'),
      (name: 'Practice', type: 'activity', xp: 100, icon: '🔁', desc: 'Skill drills, deliberate practice, and repetitions'),
      (name: 'Routine', type: 'activity', xp: 50, icon: '⏱️', desc: 'Daily protocols, check-ins, and maintenance routines'),
      (name: 'Professional', type: 'life_area', xp: 0, icon: '💼', desc: 'Career, business, and craftsmanship domains'),
      (name: 'Personal', type: 'life_area', xp: 0, icon: '🌟', desc: 'Health, vitality, mindset, and family domains'),
    ];

    await transaction(() async {
      for (final cat in defaults) {
        final catId = Id.uuidV7().value;
        await into(db.categories).insert(
          CategoriesCompanion(
            id: Value(catId),
            ownerId: Value(ownerId),
            name: Value(cat.name),
            categoryType: Value(cat.type),
            description: Value(cat.desc),
            icon: Value(cat.icon),
            baseXp: Value(cat.xp),
            isImmutable: const Value(false),
            sortOrder: const Value(0),
            versionHlc: Value(hlc),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // Freeze initial SCD Type 2 rule version snapshot (Invariant #9)
        final snapshot = {
          'base_xp': cat.xp,
          'actions': <Map<String, dynamic>>[],
        };
        await into(db.categoryXpRuleVersions).insert(
          CategoryXpRuleVersionsCompanion(
            id: Value(Id.uuidV7().value),
            categoryId: Value(catId),
            snapshot: Value(jsonEncode(snapshot)),
            effectiveFrom: Value(now),
            createdAt: Value(now),
          ),
        );
      }
    });
  }

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

  /// Fetch all active categories of a given type ('life_area', 'goal', 'task', 'activity').
  Future<List<Category>> categoriesByType(String ownerId, String categoryType) =>
      (select(db.categories)
            ..where((c) =>
                c.ownerId.equals(ownerId) &
                c.categoryType.equals(categoryType) &
                c.archivedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
          .get();

  /// Watch active categories of a given type.
  Stream<List<Category>> watchCategoriesByType(String ownerId, String categoryType) =>
      (select(db.categories)
            ..where((c) =>
                c.ownerId.equals(ownerId) &
                c.categoryType.equals(categoryType) &
                c.archivedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
          .watch();

  /// Fetch all categories of a given type including archived.
  Future<List<Category>> allCategoriesByType(String ownerId, String categoryType) =>
      (select(db.categories)
            ..where((c) =>
                c.ownerId.equals(ownerId) &
                c.categoryType.equals(categoryType))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
          .get();

  /// Watch all categories of a given type including archived.
  Stream<List<Category>> watchAllCategoriesByType(String ownerId, String categoryType) =>
      (select(db.categories)
            ..where((c) =>
                c.ownerId.equals(ownerId) &
                c.categoryType.equals(categoryType))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
          .watch();

  /// Simple upsert category.
  Future<void> upsertCategory(CategoriesCompanion category) =>
      into(db.categories).insertOnConflictUpdate(category);

  /// Archive category.
  Future<void> archiveCategory(String categoryId, String versionHlc) =>
      (update(db.categories)..where((c) => c.id.equals(categoryId))).write(
        CategoriesCompanion(
          archivedAt: Value(DateTime.now().toUtc()),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Restore category.
  Future<void> restoreCategory(String categoryId, String versionHlc) =>
      (update(db.categories)..where((c) => c.id.equals(categoryId))).write(
        CategoriesCompanion(
          archivedAt: const Value(null),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Rename or edit category.
  Future<void> updateCategory({
    required String categoryId,
    required String name,
    String? description,
    String? icon,
    int? baseXp,
    int? sortOrder,
    String? versionHlc,
  }) =>
      (update(db.categories)..where((c) => c.id.equals(categoryId))).write(
        CategoriesCompanion(
          name: Value(name),
          description: Value(description),
          icon: Value(icon),
          baseXp: baseXp != null ? Value(baseXp) : const Value.absent(),
          sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
          versionHlc: versionHlc != null ? Value(versionHlc) : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Delete category permanently.
  Future<int> deleteCategory(String categoryId) =>
      (delete(db.categories)..where((c) => c.id.equals(categoryId))).go();
}
