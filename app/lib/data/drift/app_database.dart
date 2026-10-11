import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'connection/connection.dart';

import 'aux_tables.dart';
import 'core_tables.dart';
import 'ideas_tables.dart';
import 'ledger_tables.dart';
import 'progression_tables.dart';
import '../../features/tasks/data/tasks_dao.dart';
import '../../features/tasks/data/junctions_dao.dart';
import '../../features/xp/data/xp_ledger_dao.dart';
import '../../features/xp/data/xp_analytics_dao.dart';
import '../../features/progression/data/progression_dao.dart';
import '../../features/streaks/data/streaks_dao.dart';
import '../../features/categories/data/categories_dao.dart';
import '../../features/skills/data/skills_dao.dart';
import '../../features/tools/data/tools_dao.dart';
import '../../features/sessions/data/sessions_dao.dart';
import '../../features/activities/data/activities_dao.dart';
import '../../features/projects/data/projects_dao.dart';
import '../../features/notes/data/notes_dao.dart';
import '../../features/notes/data/audio_dao.dart';
import '../../features/attachments/data/attachments_dao.dart';
import '../../features/sync/data/sync_dao.dart';
import '../../features/search/data/vector_embeddings_table.dart';
import '../../features/search/data/vector_embeddings_dao.dart';
import '../../features/collaboration/data/collaboration_dao.dart';
import '../../features/collaboration/data/collaborative_notes_dao.dart';
import '../../features/goals/data/goals_dao.dart';
import '../../features/ideas/data/ideas_dao.dart';

part 'app_database.g.dart';

/// KRATOS local offline-first database.
///
/// Mirrors the Drift schema (PostgreSQL tables + VectorEmbeddings,
/// SharedGoals, GoalComments, CollaborativeNotes, CollaborativeNoteDeltas,
/// IdeaSpaces, Ideas, IdeaSpaceLinks, IdeaBlocks, IdeaLinks, Tags, IdeaTags, IdeaAttachments).
/// Platform-aware: uses Native SQLite on Android/iOS/Desktop and Wasm/IndexedDB on Web.
@DriftDatabase(
  tables: [
    // Core (0001)
    Users,
    LifeAreas,
    Categories,
    CategoryActions,
    CategoryXpRuleVersions,
    Goals,
    Projects,
    ProjectPhases,
    Tasks,
    TaskGoalLinks,
    Activities,
    Sessions,
    Decisions,
    ActivityEvents,
    // XP Ledger (0002 + Wave 5 + Wave 7)
    XpLedger,
    XpAllocationLines,
    UserStreaks,
    StreakPauses,
    StreakFreezeInventory,
    ProcessedIdempotencyKeys,
    // Sync (0003)
    SyncOutbox,
    SyncCursors,
    SyncTombstones,
    // Notes / AI / Skills / Attachments (0004)
    Notes,
    Audios,
    Achievements,
    Evidence,
    AiArtifacts,
    Files,
    Links,
    AttachmentLinks,
    Skills,
    SkillGroups,
    SkillLifeAreaLinks,
    Tools,
    SkillTools,
    TaskToolLinks,
    // Progression (0007 + Wave 6)
    LevelCurves,
    TierDefinitions,
    LevelObjectives,
    // Search / Vector Embeddings (Wave 19)
    VectorEmbeddings,
    // Collaboration (Wave 21 & 24)
    SharedGoals,
    GoalComments,
    CollaborativeNotes,
    CollaborativeNoteDeltas,
    // Idea Capture / Knowledge System (Wave 35 / 0020)
    IdeaSpaces,
    Ideas,
    IdeaSpaceLinks,
    IdeaBlocks,
    IdeaLinks,
    Tags,
    IdeaTags,
    IdeaAttachments,
  ],
  daos: [
    TasksDao,
    TaskGoalLinksDao,
    SkillToolsDao,
    TaskToolLinksDao,
    AttachmentLinksDao,
    XpLedgerDao,
    XpAnalyticsDao,
    ProgressionDao,
    StreaksDao,
    CategoriesDao,
    SkillsDao,
    ToolsDao,
    SessionsDao,
    ActivitiesDao,
    ProjectsDao,
    NotesDao,
    AudioDao,
    AttachmentsDao,
    SyncDao,
    VectorEmbeddingsDao,
    CollaborationDao,
    CollaborativeNotesDao,
    GoalsDao,
    IdeasDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      debugPrint('[AppDatabase] onCreate starting createAll...');
      await m.createAll();
      debugPrint('[AppDatabase] onCreate completed createAll successfully!');
    },
    beforeOpen: (details) async {
      debugPrint('[AppDatabase] beforeOpen: was ${details.versionBefore}, now ${details.versionNow}');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tasks, tasks.lifeAreaId);
      }
      if (from < 3) {
        await m.addColumn(lifeAreas, lifeAreas.categoryId);
      }
      if (from < 5) {
        final columns = await customSelect("PRAGMA table_info('categories')")
            .get();
        final hasCategoryType = columns.any(
          (c) => c.data['name'] == 'category_type',
        );
        if (!hasCategoryType) {
          await m.addColumn(categories, categories.categoryType);
        }
      }
      if (from < 6) {
        final columns = await customSelect("PRAGMA table_info('users')").get();
        final hasCaption = columns.any((c) => c.data['name'] == 'caption');
        if (!hasCaption) {
          await m.addColumn(users, users.caption);
        }
        final hasAvatarUrl = columns.any((c) => c.data['name'] == 'avatar_url');
        if (!hasAvatarUrl) {
          await m.addColumn(users, users.avatarUrl);
        }
        final hasEmail = columns.any((c) => c.data['name'] == 'email');
        if (!hasEmail) {
          await m.addColumn(users, users.email);
        }
      }
      if (from < 7) {
        final columns = await customSelect("PRAGMA table_info('level_curves')")
            .get();
        final hasName = columns.any((c) => c.data['name'] == 'name');
        if (!hasName) {
          await m.addColumn(levelCurves, levelCurves.name);
        }
        final hasDescription = columns.any(
          (c) => c.data['name'] == 'description',
        );
        if (!hasDescription) {
          await m.addColumn(levelCurves, levelCurves.description);
        }
        final hasCategoryId = columns.any(
          (c) => c.data['name'] == 'category_id',
        );
        if (!hasCategoryId) {
          await m.addColumn(levelCurves, levelCurves.categoryId);
        }
        final hasTierName = columns.any((c) => c.data['name'] == 'tier_name');
        if (!hasTierName) {
          await m.addColumn(levelCurves, levelCurves.tierName);
        }
      }
      if (from < 8) {
        final columns = await customSelect("PRAGMA table_info('activities')")
            .get();
        final hasTarget = columns.any(
          (c) => c.data['name'] == 'target_duration_minutes',
        );
        if (!hasTarget) {
          await m.addColumn(activities, activities.targetDurationMinutes);
        }
      }
      if (from < 9) {
        await m.createTable(ideaSpaces);
        await m.createTable(ideas);
        await m.createTable(ideaSpaceLinks);
        await m.createTable(ideaBlocks);
        await m.createTable(ideaLinks);
        await m.createTable(tags);
        await m.createTable(ideaTags);
        await m.createTable(ideaAttachments);
      }
      if (from < 10) {
        await m.addColumn(skills, skills.groupId);
        await m.addColumn(skills, skills.masteryLevel);
        await m.createTable(skillGroups);
        await m.createTable(skillLifeAreaLinks);
      }
      if (from < 11) {
        final projectCols = await customSelect("PRAGMA table_info('projects')")
            .get();
        if (!projectCols.any((c) => c.data['name'] == 'difficulty')) {
          await m.addColumn(projects, projects.difficulty);
        }
        if (!projectCols.any((c) => c.data['name'] == 'level_id')) {
          await m.addColumn(projects, projects.levelId);
        }
        if (!projectCols.any((c) => c.data['name'] == 'cover_image_path')) {
          await m.addColumn(projects, projects.coverImagePath);
        }
        if (!projectCols.any((c) => c.data['name'] == 'progress')) {
          await m.addColumn(projects, projects.progress);
        }
        final taskCols = await customSelect("PRAGMA table_info('tasks')").get();
        if (!taskCols.any((c) => c.data['name'] == 'phase_id')) {
          await m.addColumn(tasks, tasks.phaseId);
        }
        final actCols = await customSelect("PRAGMA table_info('activities')")
            .get();
        if (!actCols.any((c) => c.data['name'] == 'project_id')) {
          await m.addColumn(activities, activities.projectId);
        }
        final fileCols = await customSelect("PRAGMA table_info('files')").get();
        if (!fileCols.any((c) => c.data['name'] == 'filename')) {
          await m.addColumn(files, files.filename);
        }
        await m.createTable(projectPhases);
      }
      if (from < 12) {
        final actCols = await customSelect("PRAGMA table_info('activities')")
            .get();
        if (!actCols.any((c) => c.data['name'] == 'difficulty')) {
          await m.addColumn(activities, activities.difficulty);
        }
      }
      if (from < 13) {
        final userCols = await customSelect("PRAGMA table_info('users')").get();
        if (!userCols.any((c) => c.data['name'] == 'version_hlc')) {
          await m.addColumn(users, users.versionHlc);
        }
      }
      if (from < 14) {
        final projectCols = await customSelect("PRAGMA table_info('projects')")
            .get();
        if (!projectCols.any((c) => c.data['name'] == 'completed_at')) {
          await m.addColumn(projects, projects.completedAt);
        }
        await m.createTable(decisions);
        await m.createTable(activityEvents);
      }
      if (from < 15) {
        final sessionCols = await customSelect("PRAGMA table_info('sessions')")
            .get();
        bool has(String n) => sessionCols.any((c) => c.data['name'] == n);
        if (!has('status')) await m.addColumn(sessions, sessions.status);
        if (!has('source')) await m.addColumn(sessions, sessions.source);
        if (!has('paused_at')) await m.addColumn(sessions, sessions.pausedAt);
        if (!has('paused_total_ms')) {
          await m.addColumn(sessions, sessions.pausedTotalMs);
        }
      }
    },
  );
}

QueryExecutor _openConnection() {
  return connect('kratos_db');
}

