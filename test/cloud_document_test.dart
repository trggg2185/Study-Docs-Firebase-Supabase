import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/modified/models/document_model.dart';

void main() {
  group('DocumentModel Validation and Serialization Tests', () {
    test('Default fallback values in fromMap()', () {
      final minimalMap = {
        'id': 'doc-min',
        'title': 'Đề cương ôn tập',
        'subject': 'Hệ điều hành',
      };

      final doc = DocumentModel.fromMap(minimalMap);
      expect(doc.id, 'doc-min');
      expect(doc.title, 'Đề cương ôn tập');
      expect(doc.type, DocumentType.reference); // Default fallback
      expect(doc.fileUrl, '');
      expect(doc.ownerId, '');
      expect(doc.fileSize, 0);
    });

    test('DocumentType display names and parsing', () {
      expect(DocumentType.lecture.displayName, 'Bài giảng');
      expect(DocumentType.exercise.displayName, 'Bài tập');
      expect(DocumentType.reference.displayName, 'Tham khảo');

      expect(DocumentType.fromString('lecture'), DocumentType.lecture);
      expect(DocumentType.fromString('exercise'), DocumentType.exercise);
      expect(DocumentType.fromString('unknown'), DocumentType.reference);
    });
  });
}
