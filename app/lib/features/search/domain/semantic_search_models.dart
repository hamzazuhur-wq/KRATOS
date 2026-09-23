// ignore_for_file: public_member_api_docs
// Wave 19: Semantic Search & Vector Embeddings Domain Models.
// Mathematical foundations for cosine similarity ranking and vector normalization.

import 'dart:convert';
import 'dart:math';

class VectorEmbedding {
  final String id;
  final String ownerId;
  final String entityKind;
  final String entityId;
  final List<double> values;
  final int dimensions;
  final String modelId;
  final String versionHlc;

  const VectorEmbedding({
    required this.id,
    required this.ownerId,
    required this.entityKind,
    required this.entityId,
    required this.values,
    required this.dimensions,
    required this.modelId,
    required this.versionHlc,
  });

  String toJsonString() => jsonEncode(values);

  factory VectorEmbedding.fromJsonString({
    required String id,
    required String ownerId,
    required String entityKind,
    required String entityId,
    required String jsonString,
    required String modelId,
    required String versionHlc,
  }) {
    final list = (jsonDecode(jsonString) as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    return VectorEmbedding(
      id: id,
      ownerId: ownerId,
      entityKind: entityKind,
      entityId: entityId,
      values: list,
      dimensions: list.length,
      modelId: modelId,
      versionHlc: versionHlc,
    );
  }
}

class SearchResultItem {
  final String entityKind;
  final String entityId;
  final String title;
  final double similarityScore; // 0.0 to 1.0

  const SearchResultItem({
    required this.entityKind,
    required this.entityId,
    required this.title,
    required this.similarityScore,
  });
}

class CosineSimilarity {
  /// Computes the cosine similarity between two float vectors.
  /// Result is bounded between -1.0 and +1.0 (typically 0.0 to 1.0 for normalized embeddings).
  static double calculate(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      norm1 += v1[i] * v1[i];
      norm2 += v2[i] * v2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }
}
