/// Model thuần Dart cho tài liệu
class DocumentModel {
  final String id;
  final String title;
  final String description;
  final DocumentType type;
  final String subject;
  final String fileUrl;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String? categoryId;
  final String ownerId;
  final String ownerEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sharedPermission; // 'view' hoặc 'edit' nếu được chia sẻ
  final List<String> tags;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  const DocumentModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    required this.subject,
    this.fileUrl = '',
    this.filePath = '',
    this.fileName = '',
    this.fileSize = 0,
    this.categoryId,
    this.ownerId = '',
    this.ownerEmail = '',
    required this.createdAt,
    required this.updatedAt,
    this.sharedPermission,
    this.tags = const [],
    this.locationName,
    this.latitude,
    this.longitude,
  });

  /// Kiểm tra xem người dùng hiện tại có phải là chủ sở hữu không
  bool isOwner(String? currentUserId) =>
      currentUserId != null && ownerId == currentUserId;

  /// Tài liệu có toạ độ để hiển thị trên bản đồ hay không
  bool get hasLocation => latitude != null && longitude != null;

  /// Kiểm tra xem có quyền chỉnh sửa không (là chủ hoặc được chia sẻ quyền 'edit')
  bool canEdit(String? currentUserId) =>
      isOwner(currentUserId) || sharedPermission == 'edit';

  DocumentModel copyWith({
    String? id,
    String? title,
    String? description,
    DocumentType? type,
    String? subject,
    String? fileUrl,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? categoryId,
    String? ownerId,
    String? ownerEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sharedPermission,
    List<String>? tags,
    String? locationName,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      categoryId: categoryId ?? this.categoryId,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sharedPermission: sharedPermission ?? this.sharedPermission,
      tags: tags ?? this.tags,
      locationName: clearLocation ? null : (locationName ?? this.locationName),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
    );
  }

  /// Chuyển thành Map để lưu vào Supabase
  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'subject': subject,
      'file_url': fileUrl,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'category_id': categoryId,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'tags': tags,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Tạo model từ Supabase map
  factory DocumentModel.fromMap(
    Map<String, dynamic> map, {
    String? sharedPermission,
  }) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return DocumentModel(
      id: map['id']?.toString() ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: DocumentType.fromString(map['type'] as String? ?? 'reference'),
      subject: map['subject'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? (map['fileUrl'] as String? ?? ''),
      filePath:
          map['file_path'] as String? ?? (map['filePath'] as String? ?? ''),
      fileName:
          map['file_name'] as String? ?? (map['fileName'] as String? ?? ''),
      fileSize:
          (map['file_size'] as num?)?.toInt() ??
          ((map['fileSize'] as num?)?.toInt() ?? 0),
      categoryId:
          map['category_id'] as String? ?? (map['categoryId'] as String?),
      ownerId:
          map['owner_id']?.toString() ?? (map['ownerId']?.toString() ?? ''),
      ownerEmail:
          map['owner_email'] as String? ?? (map['ownerEmail'] as String? ?? ''),
      createdAt: parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDateTime(map['updated_at'] ?? map['updatedAt']),
      sharedPermission: sharedPermission,
      tags: _parseTags(map['tags']),
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'DocumentModel(id: $id, title: $title, type: $type, ownerId: $ownerId)';
}

/// Postgres trả text[] dạng List; hỗ trợ thêm chuỗi phân tách bằng dấu phẩy.
List<String> _parseTags(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// Enum loại tài liệu
enum DocumentType {
  lecture, // Bài giảng
  exercise, // Bài tập
  reference; // Tài liệu tham khảo

  /// Tên hiển thị tiếng Việt
  String get displayName {
    switch (this) {
      case DocumentType.lecture:
        return 'Bài giảng';
      case DocumentType.exercise:
        return 'Bài tập';
      case DocumentType.reference:
        return 'Tham khảo';
    }
  }

  /// Icon tương ứng
  String get iconName {
    switch (this) {
      case DocumentType.lecture:
        return 'school';
      case DocumentType.exercise:
        return 'assignment';
      case DocumentType.reference:
        return 'menu_book';
    }
  }

  /// Parse từ string
  static DocumentType fromString(String value) {
    return DocumentType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentType.reference,
    );
  }
}
