import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/modified/models/document_model.dart';
import 'package:test_flutter/struct/recommendation_struct.dart';

void main() {
  final now = DateTime(2026, 10, 22);

  DocumentModel document({
    required String subject,
    required DocumentType type,
    String ownerId = 'other-user',
  }) {
    return DocumentModel(
      id: '$subject-${type.name}-$ownerId',
      title: 'Tài liệu kiểm thử',
      type: type,
      subject: subject,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('RecommendationStruct.score', () {
    test('tag match scores higher than subject, then type', () {
      final candidate = document(subject: 'Toán', type: DocumentType.lecture);
      final tagScore = RecommendationStruct.score(
        candidate,
        tagWeights: {'đại số': 1},
        subjects: {'toán'},
        types: {DocumentType.lecture},
        candidateTags: ['đại số'],
      );
      final subjectScore = RecommendationStruct.score(
        candidate,
        tagWeights: const {},
        subjects: {'toán'},
        types: {DocumentType.lecture},
      );
      final typeScore = RecommendationStruct.score(
        candidate,
        tagWeights: const {},
        subjects: const {},
        types: {DocumentType.lecture},
      );

      expect(tagScore, greaterThan(subjectScore));
      expect(subjectScore, greaterThan(typeScore));
    });

    test('returns zero when there are no matching signals', () {
      final score = RecommendationStruct.score(
        document(subject: 'Vật lý', type: DocumentType.reference),
        tagWeights: const {},
        subjects: {'toán'},
        types: {DocumentType.lecture},
        candidateTags: ['quang học'],
      );

      expect(score, 0);
    });

    test('caps each matching tag weight at three', () {
      final score = RecommendationStruct.score(
        document(subject: '', type: DocumentType.reference),
        tagWeights: {'đại số': 9},
        subjects: const {},
        types: const {},
        candidateTags: ['đại số'],
      );

      expect(score, 9);
    });
  });
}
