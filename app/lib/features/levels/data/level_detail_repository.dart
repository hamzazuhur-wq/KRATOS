import 'dart:async';

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../progression/domain/progression_calculator.dart';
import 'levels_dashboard_repository.dart';

/// Read model for the Level Detail Dashboard.
class LevelDetailData {
  final int level;
  final String name;
  final String tier;
  final String tierColor;
  final String tierIcon;
  final String? description;
  final Category? category;
  final int lowerXp;
  final int upperXp;
  final int deltaXp;
  final List<LevelsDashboardEntry> linkedLifeAreas;

  const LevelDetailData({
    required this.level,
    required this.name,
    required this.tier,
    required this.tierColor,
    required this.tierIcon,
    this.description,
    this.category,
    required this.lowerXp,
    required this.upperXp,
    required this.deltaXp,
    required this.linkedLifeAreas,
  });

  LevelDetailData copyWith({
    int? level,
    String? name,
    String? tier,
    String? tierColor,
    String? tierIcon,
    String? description,
    Category? category,
    int? lowerXp,
    int? upperXp,
    int? deltaXp,
    List<LevelsDashboardEntry>? linkedLifeAreas,
  }) {
    return LevelDetailData(
      level: level ?? this.level,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      tierColor: tierColor ?? this.tierColor,
      tierIcon: tierIcon ?? this.tierIcon,
      description: description ?? this.description,
      category: category ?? this.category,
      lowerXp: lowerXp ?? this.lowerXp,
      upperXp: upperXp ?? this.upperXp,
      deltaXp: deltaXp ?? this.deltaXp,
      linkedLifeAreas: linkedLifeAreas ?? this.linkedLifeAreas,
    );
  }
}

/// Repository for the Level Detail page backed by Drift SQLite database.
class LevelDetailRepository {
  final AppDatabase _database;
  final LevelsDashboardRepository _dashboardRepo;

  LevelDetailRepository(this._database)
      : _dashboardRepo = LevelsDashboardRepository(_database);

  /// Fetch level detail data once.
  Future<LevelDetailData> getLevelDetail({
    required int level,
    required String ownerId,
  }) async {
    await _database.progressionDao.ensureSeeded();

    final curve = await _database.progressionDao.findLevel(level) ??
        _getDefaultCurveForLevel(level);

    final tiers = await _database.progressionDao.allTiers();

    final activeTier = _resolveTier(curve, tiers);
    final category = curve.categoryId != null
        ? await _database.categoriesDao.findById(curve.categoryId!)
        : null;

    final allProgressions = await _dashboardRepo.getProgressions(ownerId);
    final linkedLifeAreas = allProgressions
        .where((entry) => entry.progression.level == level)
        .toList();

    final name = curve.name?.isNotEmpty == true
        ? curve.name!
        : _computeDefaultLevelName(curve.level, activeTier.name);

    return LevelDetailData(
      level: curve.level,
      name: name,
      tier: curve.tierName ?? activeTier.name,
      tierColor: activeTier.color ?? '#EEFF08',
      tierIcon: activeTier.icon ?? 'shield',
      description: curve.description,
      category: category,
      lowerXp: curve.cumulativeXpRequired,
      upperXp: curve.cumulativeXpRequired + curve.deltaXp,
      deltaXp: curve.deltaXp,
      linkedLifeAreas: linkedLifeAreas,
    );
  }

  /// Watch level detail data reactively.
  Stream<LevelDetailData> watchLevelDetail({
    required int level,
    required String ownerId,
  }) {
    return _dashboardRepo.watchProgressions(ownerId).asyncMap((_) async {
      return getLevelDetail(level: level, ownerId: ownerId);
    });
  }

  /// Update level definition details in the database.
  Future<void> updateLevel({
    required int level,
    String? name,
    String? description,
    String? categoryId,
    String? tierName,
    int? deltaXp,
    int? cumulativeXpRequired,
  }) async {
    await _database.progressionDao.ensureSeeded();
    await _database.progressionDao.updateLevelCurve(
      level: level,
      name: name,
      description: description,
      categoryId: categoryId,
      tierName: tierName,
      deltaXp: deltaXp,
      cumulativeXpRequired: cumulativeXpRequired,
    );
  }

  /// Create or configure a new Level Definition with real Life Area Category integration.
  Future<LevelDetailData> createLevel({
    required String ownerId,
    required int level,
    required String name,
    required String tierName,
    required String? categoryId,
    String? description,
    required int minXp,
    required int maxXp,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Level name is required.');
    }
    if (minXp < 0 || maxXp <= minXp) {
      throw ArgumentError('Maximum XP ($maxXp) must be strictly greater than Minimum XP ($minXp).');
    }

    await _database.progressionDao.ensureSeeded();
    final deltaXp = maxXp - minXp;

    await _database.progressionDao.updateLevelCurve(
      level: level,
      name: name.trim(),
      description: description != null && description.trim().isNotEmpty ? description.trim() : null,
      categoryId: categoryId,
      tierName: tierName,
      deltaXp: deltaXp,
      cumulativeXpRequired: minXp,
    );

    return getLevelDetail(level: level, ownerId: ownerId);
  }

  /// Create a new Life Area Category inline from Level Creation.
  Future<Category> createLifeAreaCategory({
    required String ownerId,
    required String name,
    String? description,
    String? icon,
    int baseXp = 100,
  }) async {
    final now = DateTime.now().toUtc();
    final id = 'cat_${DateTime.now().microsecondsSinceEpoch}';
    const hlc = '0:0:1';

    final categoryCompanion = CategoriesCompanion.insert(
      id: id,
      ownerId: ownerId,
      name: name.trim(),
      description: Value(description?.trim()),
      icon: Value(icon),
      categoryType: const Value('life_area'),
      baseXp: baseXp,
      isImmutable: false,
      sortOrder: 0,
      versionHlc: hlc,
      createdAt: now,
      updatedAt: now,
    );

    await _database.categoriesDao.upsertCategory(categoryCompanion);
    final created = await _database.categoriesDao.findById(id);
    return created!;
  }

  /// Fetch active categories available for assigning to a level (uses existing Life Area categories).
  Future<List<Category>> getCategories(String ownerId) async {
    final lifeAreaCategories =
        await _database.categoriesDao.categoriesByType(ownerId, 'life_area');
    if (lifeAreaCategories.isNotEmpty) return lifeAreaCategories;
    return _database.categoriesDao.allCategories(ownerId);
  }

  /// Fetch all available tier definitions.
  Future<List<TierDefinition>> getTiers() async {
    await _database.progressionDao.ensureSeeded();
    return _database.progressionDao.allTiers();
  }

  /// Fetch all level curves configured in the database.
  Future<List<LevelDetailData>> getAllLevelsWithDetails(String ownerId) async {
    await _database.progressionDao.ensureSeeded();
    final curves = await _database.progressionDao.allCurves();
    final tiers = await _database.progressionDao.allTiers();
    final allProgressions = await _dashboardRepo.getProgressions(ownerId);

    final results = <LevelDetailData>[];
    for (final curve in curves) {
      final activeTier = _resolveTier(curve, tiers);
      final category = curve.categoryId != null
          ? await _database.categoriesDao.findById(curve.categoryId!)
          : null;
      final linked = allProgressions
          .where((entry) => entry.progression.level == curve.level)
          .toList();

      final name = curve.name?.isNotEmpty == true
          ? curve.name!
          : _computeDefaultLevelName(curve.level, activeTier.name);

      results.add(LevelDetailData(
        level: curve.level,
        name: name,
        tier: curve.tierName ?? activeTier.name,
        tierColor: activeTier.color ?? '#EEFF08',
        tierIcon: activeTier.icon ?? 'shield',
        description: curve.description,
        category: category,
        lowerXp: curve.cumulativeXpRequired,
        upperXp: curve.cumulativeXpRequired + curve.deltaXp,
        deltaXp: curve.deltaXp,
        linkedLifeAreas: linked,
      ));
    }
    return results;
  }

  TierDefinition _resolveTier(LevelCurve curve, List<TierDefinition> tiers) {
    if (curve.tierName != null) {
      final matching = tiers.where((t) => t.name.toLowerCase() == curve.tierName!.toLowerCase());
      if (matching.isNotEmpty) return matching.first;
    }

    // Match by cumulative XP threshold
    TierDefinition best = tiers.first;
    for (final tier in tiers) {
      if (curve.cumulativeXpRequired >= tier.entryXp) {
        best = tier;
      }
    }
    return best;
  }

  String _computeDefaultLevelName(int level, String tierName) {
    return '$tierName ${RomanNumerals.toRoman(level)}';
  }

  LevelCurve _getDefaultCurveForLevel(int level) {
    final defaultCurve = ProgressionCalculator.defaultCurves.firstWhere(
      (c) => c.level == level,
      orElse: () => ProgressionCalculator.defaultCurves.first,
    );
    return LevelCurve(
      level: defaultCurve.level,
      deltaXp: defaultCurve.deltaXp,
      cumulativeXpRequired: defaultCurve.cumulativeXpRequired,
      name: null,
      description: null,
      categoryId: null,
      tierName: null,
    );
  }
}

/// Helper for clean Roman numeral level designations (e.g. I, II, III, IV, V).
class RomanNumerals {
  static String toRoman(int number) {
    if (number <= 0) return '$number';
    final mod = ((number - 1) % 5) + 1;
    switch (mod) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      default:
        return '$number';
    }
  }
}
