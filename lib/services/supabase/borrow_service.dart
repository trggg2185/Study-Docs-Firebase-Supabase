import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modified/models/borrow_request_model.dart';
import '../../modified/models/document_model.dart';
import 'supabase_service.dart';

/// Dịch vụ quản lý yêu cầu mượn tài liệu học tập và thông báo realtime.
/// Tương ứng với bảng `borrow_requests` trong Supabase.
class BorrowService {
  final SupabaseService _supabaseService;

  BorrowService(SupabaseService service) : _supabaseService = service;

  SupabaseClient get _client => _supabaseService.client;
  String? get _currentUserId => _supabaseService.currentUserId;
  String? get _currentUserEmail => _supabaseService.currentUserEmail;

  /// Gửi yêu cầu mượn tài liệu
  Future<String> request({
    required DocumentModel document,
    String message = '',
  }) async {
    final requesterId = _currentUserId;
    final requesterEmail = _currentUserEmail;

    if (requesterId == null || requesterEmail == null) {
      throw StateError('Vui lòng đăng nhập để mượn tài liệu');
    }

    if (document.ownerId == requesterId) {
      throw ArgumentError('Không thể gửi yêu cầu mượn tài liệu của chính mình');
    }

    final alreadyOpen = await hasOpenRequest(document.id);
    if (alreadyOpen) {
      throw StateError('Bạn đã có yêu cầu đang chờ duyệt hoặc đang mượn tài liệu này');
    }

    final data = {
      'document_id': document.id,
      'owner_id': document.ownerId,
      'requester_id': requesterId,
      'requester_email': requesterEmail,
      'message': message.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('borrow_requests')
        .insert(data)
        .select('id')
        .single();

    return response['id'].toString();
  }

  /// Lấy yêu cầu đang mở (pending hoặc approved) của người dùng hiện tại với tài liệu
  Future<BorrowRequestModel?> getOpenRequest(String documentId) async {
    final requesterId = _currentUserId;
    if (requesterId == null) return null;

    final response = await _client
        .from('borrow_requests')
        .select('*, documents(title)')
        .eq('document_id', documentId)
        .eq('requester_id', requesterId)
        .inFilter('status', ['pending', 'approved'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return BorrowRequestModel.fromMap(response);
  }

  /// true nếu đã có yêu cầu pending hoặc approved (chưa trả) của người dùng hiện tại
  Future<bool> hasOpenRequest(String documentId) async {
    final req = await getOpenRequest(documentId);
    return req != null;
  }

  /// Lấy danh sách yêu cầu gửi đến tài liệu của tôi (dành cho tab Tôi nhận)
  Future<List<BorrowRequestModel>> getIncoming() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('borrow_requests')
        .select('*, documents(title)')
        .eq('owner_id', uid)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => BorrowRequestModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy danh sách yêu cầu tôi đã gửi (dành cho tab Tôi gửi)
  Future<List<BorrowRequestModel>> getOutgoing() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('borrow_requests')
        .select('*, documents(title)')
        .eq('requester_id', uid)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => BorrowRequestModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Realtime Stream: Yêu cầu gửi đến tài liệu của tôi (owner_id = tôi)
  Stream<List<BorrowRequestModel>> watchIncoming() {
    final uid = _currentUserId;
    if (uid == null) return const Stream.empty();

    return _client
        .from('borrow_requests')
        .stream(primaryKey: ['id'])
        .eq('owner_id', uid)
        .order('created_at', ascending: false)
        .asyncMap((rows) => _populateTitles(rows));
  }

  /// Realtime Stream: Yêu cầu tôi đã gửi đi (requester_id = tôi)
  Stream<List<BorrowRequestModel>> watchOutgoing() {
    final uid = _currentUserId;
    if (uid == null) return const Stream.empty();

    return _client
        .from('borrow_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', uid)
        .order('created_at', ascending: false)
        .asyncMap((rows) => _populateTitles(rows));
  }

  /// Hỗ trợ nạp tên tài liệu cho các dòng stream
  Future<List<BorrowRequestModel>> _populateTitles(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return <BorrowRequestModel>[];

    final docIds = rows
        .map((r) => r['document_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final docTitles = <String, String>{};
    if (docIds.isNotEmpty) {
      try {
        final docs = await _client
            .from('documents')
            .select('id, title')
            .inFilter('id', docIds);
        for (final d in docs) {
          docTitles[d['id'].toString()] = d['title']?.toString() ?? '';
        }
      } catch (_) {}
    }

    return rows.map((r) {
      final docId = r['document_id']?.toString() ?? '';
      return BorrowRequestModel.fromMap(r, fallbackTitle: docTitles[docId]);
    }).toList();
  }

  /// Duyệt yêu cầu: Cập nhật status thành 'approved' + tạo share view
  Future<void> approve(BorrowRequestModel request) async {
    final currentUid = _currentUserId;
    if (currentUid == null || currentUid != request.ownerId) {
      throw StateError('Chỉ chủ sở hữu tài liệu mới có quyền duyệt yêu cầu');
    }

    if (request.status != 'pending') {
      throw StateError('Chỉ có thể duyệt yêu cầu đang ở trạng thái pending');
    }

    // 1. Tạo/cập nhật quyền chia sẻ tài liệu với quyền 'view'
    await _supabaseService.shareDocument(
      documentId: request.documentId,
      email: request.requesterEmail,
      permission: 'view',
    );

    // 2. Cập nhật trạng thái yêu cầu sang 'approved'
    final now = DateTime.now();
    await _client.from('borrow_requests').update({
      'status': 'approved',
      'responded_at': now.toIso8601String(),
    }).eq('id', request.id);
  }

  /// Từ chối yêu cầu: Chỉ đổi status thành 'rejected'
  Future<void> reject(BorrowRequestModel request) async {
    final currentUid = _currentUserId;
    if (currentUid == null || currentUid != request.ownerId) {
      throw StateError('Chỉ chủ sở hữu tài liệu mới có quyền từ chối yêu cầu');
    }

    if (request.status != 'pending') {
      throw StateError('Chỉ có thể từ chối yêu cầu đang ở trạng thái pending');
    }

    final now = DateTime.now();
    await _client.from('borrow_requests').update({
      'status': 'rejected',
      'responded_at': now.toIso8601String(),
    }).eq('id', request.id);
  }

  /// Đánh dấu đã trả: Xóa quyền share tài liệu + đổi status thành 'returned'
  Future<void> markReturned(BorrowRequestModel request) async {
    final currentUid = _currentUserId;
    if (currentUid == null || currentUid != request.ownerId) {
      throw StateError('Chỉ chủ sở hữu tài liệu mới có quyền đánh dấu đã trả');
    }

    if (request.status != 'approved') {
      throw StateError(
        'Chỉ có thể đánh dấu đã trả cho yêu cầu đã được duyệt (approved)',
      );
    }

    // 1. Xóa quyền chia sẻ tài liệu tương ứng
    await _client
        .from('document_shares')
        .delete()
        .eq('document_id', request.documentId)
        .eq('shared_with_email', request.requesterEmail.toLowerCase().trim());

    // 2. Cập nhật trạng thái sang 'returned'
    final now = DateTime.now();
    await _client.from('borrow_requests').update({
      'status': 'returned',
      'responded_at': now.toIso8601String(),
    }).eq('id', request.id);
  }

  /// Đăng ký lắng nghe sự kiện Realtime bảng `borrow_requests`
  /// để hiển thị thông báo ngay khi có sự thay đổi.
  /// Caller chịu trách nhiệm lưu lại và gọi [unsubscribeRealtime] trong `dispose()`.
  RealtimeChannel subscribeRealtimeNotifications({
    void Function(BorrowRequestModel request)? onNewIncomingRequest,
    void Function(BorrowRequestModel request)? onRequestStatusChanged,
  }) {
    final currentUid = _currentUserId;
    final channel = _client.channel(
      'borrow_requests_rt_${DateTime.now().microsecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'borrow_requests',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final req = BorrowRequestModel.fromMap(record);

            if (payload.eventType == PostgresChangeEvent.insert) {
              if (currentUid != null && req.ownerId == currentUid) {
                onNewIncomingRequest?.call(req);
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              if (currentUid != null && req.requesterId == currentUid) {
                onRequestStatusChanged?.call(req);
              }
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Hủy subscription Realtime
  Future<void> unsubscribeRealtime(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  /// Xin quyền và cập nhật FCM Token cho người dùng hiện tại
  static Future<String?> setupFcmToken(SupabaseService supabaseService) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        final uid = supabaseService.currentUserId;
        if (token != null && uid != null) {
          await supabaseService.updateFcmToken(uid, token);
        }

        messaging.onTokenRefresh.listen((newToken) {
          final currentUid = supabaseService.currentUserId;
          if (currentUid != null) {
            supabaseService.updateFcmToken(currentUid, newToken);
          }
        });
        return token;
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo Firebase Messaging FCM: $e');
    }
    return null;
  }
}
