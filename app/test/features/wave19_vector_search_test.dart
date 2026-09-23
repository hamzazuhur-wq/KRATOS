// Wave 19: Unit tests for Semantic Search & Cosine Similarity Ranking.

import 'package:test/test.dart';
import '../../lib/features/search/domain/semantic_search_models.dart';

void main() {
  group('Cosine Similarity Algorithm', () {
    test('identical vectors produce similarity of 1.0', () {
      final v = [0.5, 0.5, 0.5, 0.5];
      final score = CosineSimilarity.calculate(v, v);
      expect(score, closeTo(1.0, 0.0001));
    });

    test('orthogonal vectors produce similarity of 0.0', () {
      final v1 = [1.0, 0.0];
      final v2 = [0.0, 1.0];
      final score = CosineSimilarity.calculate(v1, v2);
      expect(score, closeTo(0.0, 0.0001));
    });

    test('opposite vectors produce similarity of -1.0', () {
      final v1 = [1.0, 2.0];
      final v2 = [-1.0, -2.0];
      final score = CosineSimilarity.calculate(v1, v2);
      expect(score, closeTo(-1.0, 0.0001));
    });

    test('empty or mismatched vectors return 0.0 safely', () {
      expect(CosineSimilarity.calculate([], []), equals(0.0));
      expect(CosineSimilarity.calculate([1.0], [1.0, 2.0]), equals(0.0));
    });
  });

  group('VectorEmbedding serialization', () {
    test('converts to and from json string losslessly', () {
      final original = VectorEmbedding(
        id: 'emb_01',
        ownerId: 'usr_01',
        entityKind: 'goals',
        entityId: 'goal_01',
        values: [0.123, -0.456, 0.789],
        dimensions: 3,
        modelId: 'bge-small',
        versionHlc: '0191ebc4-test',
      );

      final jsonStr = original.toJsonString();
      final reconstructed = VectorEmbedding.fromJsonString(
        id: original.id,
        ownerId: original.ownerId,
        entityKind: original.entityKind,
        entityId: original.entityId,
        jsonString: jsonStr,
        modelId: original.modelId,
        versionHlc: original.versionHlc,
      );

      expect(reconstructed.values.length, equals(3));
      expect(reconstructed.values[0], closeTo(0.123, 0.001));
      expect(reconstructed.values[1], closeTo(-0.456, 0.001));
      expect(reconstructed.values[2], closeTo(0.789, 0.001));
    });
  });
}
