// ignore_for_file: public_member_api_docs
// Wave 11: Drift DAO for Audio (voice memos) and Achievements.
// Voice memos: captured audio clips with transcription status.
// Achievements: gamification badges awarded after XP milestones.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'audio_dao.g.dart';

@DriftAccessor(tables: [Audios, Achievements])
class AudioDao extends DatabaseAccessor<AppDatabase> with _$AudioDaoMixin {
  AudioDao(super.db);

  // ─── Voice Memos ──────────────────────────────────────────────────────

  Future<List<Audio>> allAudios(String ownerId) =>
      (select(db.audios)
            ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.desc(a.capturedAt)]))
          .get();

  Future<List<Audio>> audioForSession(String sessionId) =>
      (select(db.audios)
            ..where(
                (a) => a.sessionId.equals(sessionId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.desc(a.capturedAt)]))
          .get();

  Future<void> upsert(AudiosCompanion companion) =>
      into(db.audios).insertOnConflictUpdate(companion);

  /// Update transcription text after cloud processing completes.
  Future<void> updateTranscription(
          String audioId, String text, String status) =>
      (update(db.audios)..where((a) => a.id.equals(audioId))).write(
        AudiosCompanion(
          transcriptionText: Value(text),
          transcriptionStatus: Value(status),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> softDelete(
          String audioId, String deletedBy, String versionHlc) =>
      (update(db.audios)..where((a) => a.id.equals(audioId))).write(
        AudiosCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  // ─── Achievements ────────────────────────────────────────────────────

  Future<List<Achievement>> allAchievements(String ownerId) =>
      (select(db.achievements)
            ..where((a) => a.ownerId.equals(ownerId))
            ..orderBy([(a) => OrderingTerm.desc(a.awardedAt)]))
          .get();

  Future<void> insertAchievement(AchievementsCompanion companion) =>
      into(db.achievements).insert(companion);
}
