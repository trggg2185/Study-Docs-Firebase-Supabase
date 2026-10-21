import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_flutter/modified/models/document_model.dart';
import 'package:test_flutter/modified/models/document_share_model.dart';
import 'package:test_flutter/services/supabase/supabase_service.dart';
import 'package:test_flutter/struct/document_struct.dart';

class _FakeSupabaseService implements SupabaseService {
  bool uploadBytesCalled = false;
  bool createDocumentCalled = false;

  @override
  SupabaseClient get client =>
      SupabaseClient('https://example.supabase.co', 'anon-key');

  @override
  fb.User? get currentUser => null;

  @override
  String? get currentUserId => 'user_123';

  @override
  String? get currentUserEmail => 'user@example.com';

  @override
  Future<void> ensureProfile({
    required String uid,
    required String email,
    String fullName = '',
  }) async {}

  @override
  Future<Map<String, dynamic>?> getProfile(String uid) async => null;

  @override
  Future<void> updateInterests(String uid, List<String> interests) async {}

  @override
  Future<void> updateFcmToken(String uid, String? token) async {}

  @override
  Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    uploadBytesCalled = true;
    return {
      'fileUrl': 'https://example.com/$fileName',
      'filePath': 'user_123/$fileName',
      'fileName': fileName,
      'fileSize': bytes.length,
    };
  }

  @override
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    String? customFileName,
  }) async {
    return await uploadBytes(
      bytes: await file.readAsBytes(),
      fileName: customFileName ?? file.path.split('/').last,
    );
  }

  @override
  Future<void> deleteStorageFile(String filePath) async {}

  @override
  Future<List<DocumentModel>> getDocuments({
    String? query,
    DocumentType? type,
    String? subject,
    List<String>? tags,
    bool onlyShared = false,
  }) async {
    return <DocumentModel>[];
  }

  @override
  Future<DocumentModel?> getDocumentById(String id) async => null;

  @override
  Future<String> createDocument({
    required String title,
    String description = '',
    required DocumentType type,
    required String subject,
    String fileUrl = '',
    String filePath = '',
    String fileName = '',
    int fileSize = 0,
    List<String> tags = const [],
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    createDocumentCalled = true;
    return 'doc-123';
  }

  @override
  Future<void> updateDocument({
    required String id,
    required String title,
    String description = '',
    required DocumentType type,
    required String subject,
    String? fileUrl,
    String? filePath,
    String? fileName,
    int? fileSize,
    List<String> tags = const [],
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {}

  @override
  Future<void> deleteDocument(String id, {String? filePath}) async {}

  @override
  Future<List<DocumentShareModel>> getDocumentShares(String documentId) async {
    return <DocumentShareModel>[];
  }

  @override
  Future<void> shareDocument({
    required String documentId,
    required String email,
    String permission = 'view',
  }) async {}

  @override
  Future<void> removeShare(String shareId) async {}
}

void main() {
  group('DocumentModel Supabase Tests', () {
    test('toMap() and fromMap() serialize properly with Supabase fields', () {
      final now = DateTime(2026, 10, 13, 12, 0, 0);
      final model = DocumentModel(
        id: 'doc-123',
        title: 'Lập trình Supabase với Flutter',
        description: 'Tài liệu môn học tổng hợp',
        type: DocumentType.lecture,
        subject: 'Lập trình Di Động',
        fileUrl: 'https://pfpivszvmsiwhgpaqywj.supabase.co/storage/v1/object/public/study-docs/slide.pdf',
        filePath: 'user_123/slide.pdf',
        fileName: 'slide.pdf',
        fileSize: 1048576,
        ownerId: 'user_xyz_789',
        ownerEmail: 'user@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['title'], 'Lập trình Supabase với Flutter');
      expect(map['type'], 'lecture');
      expect(map['file_url'], contains('supabase.co'));
      expect(map['owner_id'], 'user_xyz_789');

      final restored = DocumentModel.fromMap(map);
      expect(restored.id, 'doc-123');
      expect(restored.title, model.title);
      expect(restored.type, DocumentType.lecture);
      expect(restored.subject, model.subject);
      expect(restored.fileUrl, model.fileUrl);
      expect(restored.ownerId, model.ownerId);
      expect(restored.fileName, model.fileName);
      expect(restored.fileSize, model.fileSize);
    });

    test('isOwner() and canEdit() check permissions correctly', () {
      final doc = DocumentModel(
        id: 'doc-1',
        title: 'Toán cao cấp',
        type: DocumentType.lecture,
        subject: 'Toán',
        ownerId: 'owner_123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(doc.isOwner('owner_123'), isTrue);
      expect(doc.isOwner('other_user'), isFalse);
      expect(doc.canEdit('owner_123'), isTrue);
      expect(doc.canEdit('other_user'), isFalse);

      final sharedDocWithEdit = doc.copyWith(sharedPermission: 'edit');
      expect(sharedDocWithEdit.canEdit('other_user'), isTrue);

      final sharedDocWithView = doc.copyWith(sharedPermission: 'view');
      expect(sharedDocWithView.canEdit('other_user'), isFalse);
    });
  });

  group('DocumentShareModel Tests', () {
    test('toMap() and fromMap() serialize properly', () {
      final share = DocumentShareModel(
        id: 'share-1',
        documentId: 'doc-1',
        sharedWithEmail: 'friend@gmail.com',
        permission: 'edit',
        createdAt: DateTime.now(),
      );

      final map = share.toMap();
      expect(map['document_id'], 'doc-1');
      expect(map['shared_with_email'], 'friend@gmail.com');
      expect(map['permission'], 'edit');

      final restored = DocumentShareModel.fromMap(map);
      expect(restored.documentId, 'doc-1');
      expect(restored.sharedWithEmail, 'friend@gmail.com');
      expect(restored.permission, 'edit');
    });
  });

  group('DocumentStruct web upload', () {
    test(
      'create() uploads selected bytes when file is chosen on web',
      () async {
        final service = _FakeSupabaseService();
        final documentStruct = DocumentStruct(service);

        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final docId = await documentStruct.create(
          title: 'Demo web file',
          type: DocumentType.lecture,
          subject: 'Lập trình',
          fileBytes: bytes,
          customFileName: 'demo.pdf',
        );

        expect(docId, 'doc-123');
        expect(service.uploadBytesCalled, isTrue);
        expect(service.createDocumentCalled, isTrue);
      },
    );
  });
}
