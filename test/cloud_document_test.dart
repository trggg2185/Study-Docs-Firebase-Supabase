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

    test('Tags and location serialize/deserialize', () {
      final now = DateTime(2026, 10, 21);
      final doc = DocumentModel(
        id: 'doc-new',
        title: 'Flutter nâng cao',
        type: DocumentType.lecture,
        subject: 'Lập trình di động',
        ownerId: 'uid-1',
        createdAt: now,
        updatedAt: now,
        tags: const ['flutter', 'mobile'],
        locationName: 'Kệ A3 - Phòng 201',
        latitude: 10.7769,
        longitude: 106.7009,
      );

      final map = doc.toMap();
      expect(map['tags'], ['flutter', 'mobile']);
      expect(map['location_name'], 'Kệ A3 - Phòng 201');

      final restored = DocumentModel.fromMap(map);
      expect(restored.tags, ['flutter', 'mobile']);
      expect(restored.locationName, 'Kệ A3 - Phòng 201');
      expect(restored.hasLocation, isTrue);
      expect(restored.latitude, 10.7769);
    });

    test('fromMap parses tag string and missing location', () {
      final doc = DocumentModel.fromMap({
        'id': 'doc-2',
        'title': 'Tài liệu cũ',
        'subject': 'Toán',
        'tags': 'flutter, mobile, flutter',
      });

      expect(doc.tags, ['flutter', 'mobile', 'flutter']);
      expect(doc.locationName, isNull);
      expect(doc.hasLocation, isFalse);
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
