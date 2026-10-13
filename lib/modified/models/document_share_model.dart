/// Model đại diện cho quyền chia sẻ tài liệu
class DocumentShareModel {
  final String id;
  final String documentId;
  final String sharedWithEmail;
  final String permission; // 'view' hoặc 'edit'
  final DateTime createdAt;

  const DocumentShareModel({
    required this.id,
    required this.documentId,
    required this.sharedWithEmail,
    required this.permission,
    required this.createdAt,
  });

  factory DocumentShareModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return DocumentShareModel(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      sharedWithEmail: map['shared_with_email'] as String? ?? '',
      permission: map['permission'] as String? ?? 'view',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'document_id': documentId,
      'shared_with_email': sharedWithEmail.toLowerCase().trim(),
      'permission': permission,
    };
  }
}
