// ignore_for_file: public_member_api_docs
// Wave 8: Drift DAO for Tools.
// ADR-004: Separate tools table (tools are inventory; skills are graded competencies).

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'tools_dao.g.dart';

@DriftAccessor(tables: [Tools])
class ToolsDao extends DatabaseAccessor<AppDatabase> with _$ToolsDaoMixin {
  ToolsDao(super.db);

  Future<List<Tool>> allTools(String ownerId) => (select(db.tools)
        ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<Tool?> findById(String id) =>
      (select(db.tools)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ToolsCompanion companion) =>
      into(db.tools).insertOnConflictUpdate(companion);

  Future<void> softDelete(String toolId, String deletedBy, String versionHlc) =>
      (update(db.tools)..where((t) => t.id.equals(toolId))).write(
        ToolsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
