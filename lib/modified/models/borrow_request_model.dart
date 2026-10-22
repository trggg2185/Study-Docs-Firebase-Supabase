/// Model đại diện cho một yêu cầu mượn tài liệu học tập.
/// Tương ứng với bảng `borrow_requests` trong Supabase.
class BorrowRequestModel {
  final String id;
  final String documentId;
  final String documentTitle; // join để hiển thị
  final String ownerId;
  final String requesterId;
  final String requesterEmail;
  final String message;
  final String status; // pending | approved | rejected | returned
  final DateTime createdAt;
  final DateTime? respondedAt;

  const BorrowRequestModel({
    required this.id,
    required this.documentId,
    this.documentTitle = '',
    required this.ownerId,
    required this.requesterId,
    required this.requesterEmail,
    this.message = '',
    this.status = 'pending',
    required this.createdAt,
    this.respondedAt,
  });

  /// Chuyển từ JSON/Map (từ Supabase PostgREST) sang BorrowRequestModel.
  factory BorrowRequestModel.fromMap(
    Map<String, dynamic> map, {
    String? fallbackTitle,
  }) {
    String docTitle = '';
    if (map['documents'] is Map && (map['documents'] as Map)['title'] != null) {
      docTitle = (map['documents'] as Map)['title']?.toString() ?? '';
    } else if (map['document_title'] != null &&
        map['document_title'].toString().isNotEmpty) {
      docTitle = map['document_title'].toString();
    } else if (map['title'] != null && map['title'].toString().isNotEmpty) {
      docTitle = map['title'].toString();
    } else if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      docTitle = fallbackTitle;
    }

    DateTime parsedCreated;
    final createdVal = map['created_at'];
    if (createdVal is DateTime) {
      parsedCreated = createdVal;
    } else if (createdVal != null) {
      parsedCreated =
          DateTime.tryParse(createdVal.toString()) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedResponded;
    final respondedVal = map['responded_at'];
    if (respondedVal is DateTime) {
      parsedResponded = respondedVal;
    } else if (respondedVal != null) {
      parsedResponded = DateTime.tryParse(respondedVal.toString());
    }

    return BorrowRequestModel(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      documentTitle: docTitle,
      ownerId: map['owner_id']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      requesterEmail: map['requester_email']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: parsedCreated,
      respondedAt: parsedResponded,
    );
  }

  /// Chuyển thành Map để lưu vào Supabase.
  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'document_id': documentId,
      'owner_id': ownerId,
      'requester_id': requesterId,
      'requester_email': requesterEmail,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
    };
  }

  BorrowRequestModel copyWith({
    String? id,
    String? documentId,
    String? documentTitle,
    String? ownerId,
    String? requesterId,
    String? requesterEmail,
    String? message,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return BorrowRequestModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      ownerId: ownerId ?? this.ownerId,
      requesterId: requesterId ?? this.requesterId,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isReturned => status == 'returned';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Đang chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Đã từ chối';
      case 'returned':
        return 'Đã trả';
      default:
        return status;
    }
  }

  /// Kiểm tra xem người dùng hiện tại có quyền duyệt yêu cầu hay không
  bool canApprove(String? currentUserId) =>
      currentUserId != null && currentUserId == ownerId && isPending;

  /// Kiểm tra xem người dùng hiện tại có quyền từ chối yêu cầu hay không
  bool canReject(String? currentUserId) =>
      currentUserId != null && currentUserId == ownerId && isPending;

  /// Kiểm tra xem người dùng hiện tại có quyền đánh dấu đã trả hay không
  bool canMarkReturned(String? currentUserId) =>
      currentUserId != null && currentUserId == ownerId && isApproved;

  /// Chuyển đổi trạng thái với đầy đủ kiểm tra nghiệp vụ
  BorrowRequestModel transitionTo(String nextStatus, {String? currentUserId}) {
    if (currentUserId != null && currentUserId != ownerId) {
      throw StateError(
        'Chỉ chủ sở hữu tài liệu mới có quyền thay đổi trạng thái',
      );
    }

    if (nextStatus == 'approved') {
      if (!isPending) {
        throw StateError('Chỉ có thể duyệt yêu cầu đang ở trạng thái pending');
      }
    } else if (nextStatus == 'rejected') {
      if (!isPending) {
        throw StateError(
          'Chỉ có thể từ chối yêu cầu đang ở trạng thái pending',
        );
      }
    } else if (nextStatus == 'returned') {
      if (!isApproved) {
        throw StateError(
          'Chỉ có thể đánh dấu đã trả cho yêu cầu đã được duyệt (approved)',
        );
      }
    } else {
      throw ArgumentError('Trạng thái không hợp lệ: $nextStatus');
    }

    return copyWith(
      status: nextStatus,
      respondedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorrowRequestModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
