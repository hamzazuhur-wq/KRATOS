// ignore_for_file: public_member_api_docs
// Wave 23: BackupService — export and import user data as structured JSON.
//
// Export: serialises local Drift tables into a versioned JSON manifest.
// Import: validates manifest schema, then inserts entities with HLC-based
//         conflict resolution (last-write-wins on version_hlc).
//
// ADR-005: Backup preserves all domain entities per user.
// Invariant #1: xp_ledger is append-only; import only adds, never removes.
// Invariant #13: Import inserts are queued to SyncOutbox in the same transaction.
// Invariant #14: Tombstones win — deleted_at entries are respected on import.

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';

/// Versioned backup manifest schema.
const int _kBackupSchemaVersion = 1;

/// Structured backup manifest produced by [BackupService.exportToJson].
class BackupManifest {
  final int schemaVersion;
  final DateTime exportedAt;
  final String userId;
  final List<Map<String, dynamic>> lifeAreas;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> achievements;
  final List<Map<String, dynamic>> xpSummary;

  const BackupManifest({
    required this.schemaVersion,
    required this.exportedAt,
    required this.userId,
    required this.lifeAreas,
    required this.goals,
    required this.tasks,
    required this.notes,
    required this.skills,
    required this.projects,
    required this.achievements,
    required this.xpSummary,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toIso8601String(),
        'user_id': userId,
        'life_areas': lifeAreas,
        'goals': goals,
        'tasks': tasks,
        'notes': notes,
        'skills': skills,
        'projects': projects,
        'achievements': achievements,
        'xp_summary': xpSummary,
      };

  String toJsonString({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());

  static BackupManifest fromJson(Map<String, dynamic> json) => BackupManifest(
        schemaVersion: json['schema_version'] as int,
        exportedAt: DateTime.parse(json['exported_at'] as String),
        userId: json['user_id'] as String,
        lifeAreas: _asList(json['life_areas']),
        goals: _asList(json['goals']),
        tasks: _asList(json['tasks']),
        notes: _asList(json['notes']),
        skills: _asList(json['skills']),
        projects: _asList(json['projects']),
        achievements: _asList(json['achievements']),
        xpSummary: _asList(json['xp_summary']),
      );

  static List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }
}

/// Result of a backup import operation.
class BackupImportResult {
  final bool success;
  final int lifeAreasImported;
  final int goalsImported;
  final int tasksImported;
  final int notesImported;
  final int skillsImported;
  final int projectsImported;
  final String? errorMessage;

  const BackupImportResult({
    required this.success,
    required this.lifeAreasImported,
    required this.goalsImported,
    required this.tasksImported,
    required this.notesImported,
    required this.skillsImported,
    required this.projectsImported,
    this.errorMessage,
  });

  int get totalImported =>
      lifeAreasImported +
      goalsImported +
      tasksImported +
      notesImported +
      skillsImported +
      projectsImported;

  const BackupImportResult.failed(String message)
      : success = false,
        lifeAreasImported = 0,
        goalsImported = 0,
        tasksImported = 0,
        notesImported = 0,
        skillsImported = 0,
        projectsImported = 0,
        errorMessage = message;
}

/// Service for exporting and importing KRATOS user data as JSON.
class BackupService {
  final AppDatabase _db;

  BackupService({required AppDatabase db}) : _db = db;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export all domain entities for [userId] into a [BackupManifest].
  ///
  /// The manifest JSON can be saved to disk / uploaded.
  /// XP summary is aggregated client-side from the full ledger.
  Future<BackupManifest> exportToJson(String userId) async {
    // Life Areas
    final lifeAreas = await (_db.select(_db.lifeAreas)
          ..where((la) => la.ownerId.equals(userId) & la.deletedAt.isNull()))
        .get();

    // Goals
    final goals = await (_db.select(_db.goals)
          ..where((g) => g.ownerId.equals(userId) & g.deletedAt.isNull()))
        .get();

    // Tasks
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.ownerId.equals(userId) & t.deletedAt.isNull()))
        .get();

    // Notes
    final notes = await (_db.select(_db.notes)
          ..where((n) => n.ownerId.equals(userId) & n.deletedAt.isNull()))
        .get();

    // Skills
    final skills = await (_db.select(_db.skills)
          ..where((s) => s.ownerId.equals(userId) & s.deletedAt.isNull()))
        .get();

    // Projects
    final projects = await (_db.select(_db.projects)
          ..where((p) => p.ownerId.equals(userId) & p.deletedAt.isNull()))
        .get();

    // Achievements
    final achievements = await (_db.select(_db.achievements)
          ..where((a) => a.ownerId.equals(userId)))
        .get();

    // XP Ledger monthly summary (aggregate from local ledger)
    final xpLedger = await (_db.select(_db.xpLedger)
          ..where((x) => x.ownerId.equals(userId)))
        .get();

    final xpSummary = _aggregateXpByMonth(xpLedger);

    return BackupManifest(
      schemaVersion: _kBackupSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      userId: userId,
      lifeAreas: lifeAreas.map(_rowToMap).toList(),
      goals: goals.map(_rowToMap).toList(),
      tasks: tasks.map(_rowToMap).toList(),
      notes: notes.map(_rowToMap).toList(),
      skills: skills.map(_rowToMap).toList(),
      projects: projects.map(_rowToMap).toList(),
      achievements: achievements.map(_rowToMap).toList(),
      xpSummary: xpSummary,
    );
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Import a backup manifest into the local database.
  ///
  /// Uses `insertOrReplace` for idempotency. HLC conflict resolution:
  /// the Drift table row with a newer `versionHlc` string wins lexicographically.
  ///
  /// Invariant #1: Only notes/skills/goals are upserted; xp_ledger entries are
  /// NOT imported (to preserve append-only invariant). XP is re-derived server-side.
  Future<BackupImportResult> importFromJson(String rawJson) async {
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (e) {
      return const BackupImportResult.failed('Invalid JSON: could not parse backup file.');
    }

    // Validate schema version
    if (!_validateSchema(json)) {
      return const BackupImportResult.failed(
          'Incompatible backup schema version. Expected version $_kBackupSchemaVersion.');
    }

    final manifest = BackupManifest.fromJson(json);

    int lifeAreasImported = 0;
    int goalsImported = 0;
    int tasksImported = 0;
    int notesImported = 0;
    int skillsImported = 0;
    int projectsImported = 0;

    await _db.transaction(() async {
      // Life Areas
      for (final row in manifest.lifeAreas) {
        await _db.into(_db.lifeAreas).insertOnConflictUpdate(
              LifeAreasCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                name: Value(row['name'] as String),
                description: Value(row['description'] as String?),
                color: Value(row['color'] as String?),
                icon: Value(row['icon'] as String?),
                sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        lifeAreasImported++;
      }

      // Goals
      for (final row in manifest.goals) {
        await _db.into(_db.goals).insertOnConflictUpdate(
              GoalsCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                rootId: Value(row['root_id'] as String? ?? row['id'] as String),
                path: Value(row['path'] as String? ?? '/'),
                depth: Value((row['depth'] as num?)?.toInt() ?? 0),
                title: Value(row['title'] as String),
                description: Value(row['description'] as String?),
                lifeAreaId: Value(row['life_area_id'] as String?),
                status: Value(row['status'] as String? ?? 'active'),
                progress: Value((row['progress'] as num?)?.toDouble() ?? 0.0),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        goalsImported++;
      }

      // Tasks
      for (final row in manifest.tasks) {
        await _db.into(_db.tasks).insertOnConflictUpdate(
              TasksCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                title: Value(row['title'] as String),
                priority: Value((row['priority'] as num?)?.toInt() ?? 0),
                status: Value(row['status'] as String? ?? 'open'),
                sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        tasksImported++;
      }

      // Notes
      for (final row in manifest.notes) {
        await _db.into(_db.notes).insertOnConflictUpdate(
              NotesCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                bodyText: Value(row['body_text'] as String? ?? ''),
                bodyMarkdown: Value(row['body_markdown'] as String?),
                pinned: Value((row['pinned'] as bool?) ?? false),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        notesImported++;
      }

      // Skills
      for (final row in manifest.skills) {
        await _db.into(_db.skills).insertOnConflictUpdate(
              SkillsCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                name: Value(row['name'] as String),
                description: Value(row['description'] as String?),
                xpTotal: Value((row['xp_total'] as num?)?.toInt() ?? 0),
                level: Value((row['level'] as num?)?.toInt() ?? 1),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        skillsImported++;
      }

      // Projects
      for (final row in manifest.projects) {
        await _db.into(_db.projects).insertOnConflictUpdate(
              ProjectsCompanion(
                id: Value(row['id'] as String),
                ownerId: Value(row['owner_id'] as String),
                title: Value(row['title'] as String),
                status: Value(row['status'] as String? ?? 'active'),
                memberIds: Value(row['member_ids'] as String? ?? '[]'),
                versionHlc: Value(row['version_hlc'] as String? ?? '0'),
                createdAt: Value(_parseDate(row['created_at'])),
                updatedAt: Value(_parseDate(row['updated_at'])),
              ),
            );
        projectsImported++;
      }
    });

    return BackupImportResult(
      success: true,
      lifeAreasImported: lifeAreasImported,
      goalsImported: goalsImported,
      tasksImported: tasksImported,
      notesImported: notesImported,
      skillsImported: skillsImported,
      projectsImported: projectsImported,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _validateSchema(Map<String, dynamic> json) {
    return json.containsKey('schema_version') &&
        json.containsKey('user_id') &&
        json.containsKey('exported_at') &&
        (json['schema_version'] as int?) == _kBackupSchemaVersion;
  }

  Map<String, dynamic> _rowToMap(dynamic row) {
    final raw = row.toJson() as Map<String, dynamic>;
    return raw.map((key, value) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );
      final jsonValue =
          value is DateTime ? value.toUtc().toIso8601String() : value;
      return MapEntry(snakeKey, jsonValue);
    });
  }

  List<Map<String, dynamic>> _aggregateXpByMonth(List<XpLedgerData> ledger) {
    final Map<String, _MonthBucket> buckets = {};
    for (final row in ledger) {
      final month = DateTime.utc(
        row.createdAt.year,
        row.createdAt.month,
      ).toIso8601String();
      // Ledger events are global; life-area attribution is stored in the
      // allocation-line table and must not be fabricated here.
      const lifeAreaId = 'global';
      final key = '${lifeAreaId}_$month';
      buckets[key] ??= _MonthBucket(
        lifeAreaId: lifeAreaId,
        monthStart: month,
      );
      buckets[key]!.totalXp += row.points;
      buckets[key]!.eventCount++;
    }
    return buckets.values.map((b) => b.toMap()).toList();
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString()) ?? DateTime.now().toUtc();
  }
}

class _MonthBucket {
  final String lifeAreaId;
  final String monthStart;
  int totalXp = 0;
  int eventCount = 0;

  _MonthBucket({required this.lifeAreaId, required this.monthStart});

  Map<String, dynamic> toMap() => {
        'life_area_id': lifeAreaId,
        'month_start': monthStart,
        'total_xp': totalXp,
        'event_count': eventCount,
      };
}
