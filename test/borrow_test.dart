import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_flutter/modified/models/borrow_request_model.dart';
import 'package:test_flutter/modified/models/document_model.dart';
import 'package:test_flutter/modified/models/document_share_model.dart';
import 'package:test_flutter/services/supabase/borrow_service.dart';
import 'package:test_flutter/services/supabase/supabase_service.dart';

class _FakeSupabaseService implements SupabaseService {
  String? fakeUserId;
  String? fakeUserEmail;

  _FakeSupabaseService({this.fakeUserId, this.fakeUserEmail});

  @override
  SupabaseClient get client =>
      SupabaseClient('https://example.supabase.co', 'anon-key');

  @override
  fb.User? get currentUser => null;

  @override
  String? get currentUserId => fakeUserId;

  @override
  String? get currentUserEmail => fakeUserEmail;

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
    return {};
  }

  @override
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    String? customFileName,
  }) async {
    return {};
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
  group('BorrowRequestModel Tests', () {
    test('toMap() and fromMap() serialize properly', () {
      final now = DateTime(2026, 10, 22, 10, 30);
      final model = BorrowRequestModel(
        id: 'req-001',
        documentId: 'doc-001',
        documentTitle: 'Giáo trình Mạng máy tính',
        ownerId: 'owner-123',
        requesterId: 'requester-456',
        requesterEmail: 'student@example.com',
        message: 'Em xin mượn tài liệu để ôn thi ạ',
        status: 'pending',
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['id'], 'req-001');
      expect(map['document_id'], 'doc-001');
      expect(map['owner_id'], 'owner-123');
      expect(map['requester_id'], 'requester-456');
      expect(map['requester_email'], 'student@example.com');
      expect(map['message'], 'Em xin mượn tài liệu để ôn thi ạ');
      expect(map['status'], 'pending');

      final restored = BorrowRequestModel.fromMap(map);
      expect(restored.id, 'req-001');
      expect(restored.documentId, 'doc-001');
      expect(restored.ownerId, 'owner-123');
      expect(restored.requesterId, 'requester-456');
      expect(restored.requesterEmail, 'student@example.com');
      expect(restored.status, 'pending');
      expect(restored.isPending, isTrue);
      expect(restored.statusDisplay, 'Đang chờ duyệt');
    });

    test('fromMap() handles Supabase relations and fallback title', () {
      final joinedMap = {
        'id': 'req-002',
        'document_id': 'doc-002',
        'owner_id': 'owner-1',
        'requester_id': 'req-2',
        'requester_email': 'test@gmail.com',
        'status': 'approved',
        'documents': {'title': 'Toán rời rạc'},
      };

      final model = BorrowRequestModel.fromMap(joinedMap);
      expect(model.documentTitle, 'Toán rời rạc');
      expect(model.isApproved, isTrue);
      expect(model.statusDisplay, 'Đã duyệt');

      final fallbackMap = {
        'id': 'req-003',
        'document_id': 'doc-003',
        'owner_id': 'owner-1',
        'requester_id': 'req-2',
        'requester_email': 'test@gmail.com',
        'status': 'rejected',
      };

      final fallbackModel = BorrowRequestModel.fromMap(
        fallbackMap,
        fallbackTitle: 'Vật lý đại cương',
      );
      expect(fallbackModel.documentTitle, 'Vật lý đại cương');
      expect(fallbackModel.isRejected, isTrue);
      expect(fallbackModel.statusDisplay, 'Đã từ chối');
    });

    test('Status transitions: chỉ owner được duyệt/từ chối', () {
      final now = DateTime(2026, 10, 22);
      final req = BorrowRequestModel(
        id: 'req-1',
        documentId: 'doc-1',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'pending',
        createdAt: now,
      );

      // 1. Người khác không được duyệt
      expect(req.canApprove('other_user'), isFalse);
      expect(
        () => req.transitionTo('approved', currentUserId: 'other_user'),
        throwsA(isA<StateError>()),
      );

      // 2. Người khác không được từ chối
      expect(req.canReject('other_user'), isFalse);
      expect(
        () => req.transitionTo('rejected', currentUserId: 'other_user'),
        throwsA(isA<StateError>()),
      );

      // 3. Chủ sở hữu được duyệt
      expect(req.canApprove('owner_A'), isTrue);
      final approved = req.transitionTo('approved', currentUserId: 'owner_A');
      expect(approved.status, 'approved');
      expect(approved.isApproved, isTrue);

      // 4. Chủ sở hữu được từ chối
      expect(req.canReject('owner_A'), isTrue);
      final rejected = req.transitionTo('rejected', currentUserId: 'owner_A');
      expect(rejected.status, 'rejected');
      expect(rejected.isRejected, isTrue);
    });

    test('Status transitions: chỉ approved mới trả', () {
      final now = DateTime(2026, 10, 22);
      final pendingReq = BorrowRequestModel(
        id: 'req-2',
        documentId: 'doc-2',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'pending',
        createdAt: now,
      );

      // Đang pending thì không thể trả
      expect(pendingReq.canMarkReturned('owner_A'), isFalse);
      expect(
        () => pendingReq.transitionTo('returned', currentUserId: 'owner_A'),
        throwsA(isA<StateError>()),
      );

      final rejectedReq = pendingReq.copyWith(status: 'rejected');
      // Đã từ chối thì không thể trả
      expect(rejectedReq.canMarkReturned('owner_A'), isFalse);
      expect(
        () => rejectedReq.transitionTo('returned', currentUserId: 'owner_A'),
        throwsA(isA<StateError>()),
      );

      // Phải là approved mới được trả
      final approvedReq = pendingReq.copyWith(status: 'approved');
      expect(approvedReq.canMarkReturned('owner_A'), isTrue);
      final returned = approvedReq.transitionTo(
        'returned',
        currentUserId: 'owner_A',
      );
      expect(returned.status, 'returned');
      expect(returned.isReturned, isTrue);
    });

    test('Status transitions: không trả 2 lần', () {
      final now = DateTime(2026, 10, 22);
      final returnedReq = BorrowRequestModel(
        id: 'req-3',
        documentId: 'doc-3',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'returned',
        createdAt: now,
      );

      // Yêu cầu đã trả thì không thể trả lần 2
      expect(returnedReq.canMarkReturned('owner_A'), isFalse);
      expect(
        () => returnedReq.transitionTo('returned', currentUserId: 'owner_A'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BorrowService Business Rules Tests', () {
    test('Không cho phép gửi yêu cầu mượn tài liệu của chính mình', () async {
      final service = _FakeSupabaseService(
        fakeUserId: 'user_A',
        fakeUserEmail: 'userA@example.com',
      );
      final borrowService = BorrowService(service);

      final myDoc = DocumentModel(
        id: 'doc-my',
        title: 'Tài liệu của tôi',
        type: DocumentType.lecture,
        subject: 'CNTT',
        ownerId: 'user_A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => borrowService.request(document: myDoc),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Chặn gọi request khi chưa đăng nhập', () async {
      final service = _FakeSupabaseService(
        fakeUserId: null,
        fakeUserEmail: null,
      );
      final borrowService = BorrowService(service);

      final otherDoc = DocumentModel(
        id: 'doc-other',
        title: 'Tài liệu người khác',
        type: DocumentType.lecture,
        subject: 'CNTT',
        ownerId: 'user_B',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => borrowService.request(document: otherDoc),
        throwsA(isA<StateError>()),
      );
    });

    test('BorrowService: chỉ owner mới được approve/reject/markReturned', () async {
      final service = _FakeSupabaseService(
        fakeUserId: 'intruder_user',
        fakeUserEmail: 'intruder@example.com',
      );
      final borrowService = BorrowService(service);

      final req = BorrowRequestModel(
        id: 'req-test',
        documentId: 'doc-1',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Kẻ khác duyệt -> ném StateError
      expect(() => borrowService.approve(req), throwsA(isA<StateError>()));

      // Kẻ khác từ chối -> ném StateError
      expect(() => borrowService.reject(req), throwsA(isA<StateError>()));

      final approvedReq = req.copyWith(status: 'approved');
      // Kẻ khác trả -> ném StateError
      expect(
        () => borrowService.markReturned(approvedReq),
        throwsA(isA<StateError>()),
      );
    });

    test('BorrowService: chỉ yêu cầu pending mới được approve hoặc reject', () async {
      final service = _FakeSupabaseService(
        fakeUserId: 'owner_A',
        fakeUserEmail: 'ownerA@example.com',
      );
      final borrowService = BorrowService(service);

      final approvedReq = BorrowRequestModel(
        id: 'req-approved',
        documentId: 'doc-1',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'approved',
        createdAt: DateTime.now(),
      );

      // Đã approved thì không thể approve lần nữa
      expect(
        () => borrowService.approve(approvedReq),
        throwsA(isA<StateError>()),
      );
      // Đã approved thì không thể reject
      expect(
        () => borrowService.reject(approvedReq),
        throwsA(isA<StateError>()),
      );
    });

    test('BorrowService: chỉ yêu cầu approved mới được markReturned', () async {
      final service = _FakeSupabaseService(
        fakeUserId: 'owner_A',
        fakeUserEmail: 'ownerA@example.com',
      );
      final borrowService = BorrowService(service);

      final pendingReq = BorrowRequestModel(
        id: 'req-pending',
        documentId: 'doc-1',
        ownerId: 'owner_A',
        requesterId: 'requester_B',
        requesterEmail: 'b@example.com',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Đang pending thì không được markReturned
      expect(
        () => borrowService.markReturned(pendingReq),
        throwsA(isA<StateError>()),
      );

      final returnedReq = pendingReq.copyWith(status: 'returned');
      // Đã returned thì không được markReturned lần nữa (không trả 2 lần)
      expect(
        () => borrowService.markReturned(returnedReq),
        throwsA(isA<StateError>()),
      );
    });
  });
}
