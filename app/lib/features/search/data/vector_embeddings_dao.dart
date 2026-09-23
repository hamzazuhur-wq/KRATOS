// ignore_for_file: public_member_api_docs
// Wave 19: Vector Embeddings Drift DAO.
// Provides upsert and cosine-similarity ranking across stored embeddings.

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../domain/semantic_search_models.dart';
import 'vector_embeddings_table.dart';

part 'vector_embeddings_dao.g.dart';

@DriftAccessor(tables: [VectorEmbeddings])
class VectorEmbeddingsDao extends DatabaseAccessor<AppDatabase>
    with _$VectorEmbeddingsDaoMixin {
  VectorEmbeddingsDao(super.db);

  /// Upsert an embedding for an entity.
  Future<void> upsertEmbedding(VectorEmbeddingsCompanion companion) =>
      into(db.vectorEmbeddings).insertOnConflictUpdate(companion);

  /// Fetch all embeddings for a given owner and optional entity kind.
  Future<List<VectorEmbeddingData>> getEmbeddings(String ownerId, {String? entityKind}) {
    final query = select(db.vectorEmbeddings)..where((t) => t.ownerId.equals(ownerId));
    if (entityKind != null) {
      query.where((t) => t.entityKind.equals(entityKind));
    }
    return query.get();
  }

  /// Perform in-memory Cosine Similarity ranking over user's entities.
  Future<List<SearchResultItem>> searchSimilar({
    required String ownerId,
    required List<double> queryVector,
    String? entityKind,
    int topK = 10,
    double minSimilarity = 0.50,
  }) async {
    final rows = await getEmbeddings(ownerId, entityKind: entityKind);
    final results = <SearchResultItem>[];

    for (final row in rows) {
      try {
        final parsed = (jsonDecode(row.embeddingJson) as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();

        final score = CosineSimilarity.calculate(queryVector, parsed);
        if (score >= minSimilarity) {
          results.add(
            SearchResultItem(
              entityKind: row.entityKind,
              entityId: row.entityId,
              title: '${row.entityKind.toUpperCase()}: ${row.entityId.substring(0, 8)}',
              similarityScore: score,
            ),
          );
        }
      } catch (_) {
        // Skip corrupted row gracefully
      }
    }

    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return results.take(topK).toList();
  }
}
