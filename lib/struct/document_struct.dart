import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../modified/models/document_model.dart';
import '../modified/models/document_share_model.dart';
import '../services/supabase/supabase_service.dart';
import 'location_data.dart';

/// Business logic cho tài liệu - tầng struct
/// Điều phối giữa Supabase Database, Storage và UI
class DocumentStruct {
  final SupabaseService _service;

  // StreamController để phát tín hiệu cập nhật danh sách tài liệu phản ứng
  final _documentsController =
      StreamController<List<DocumentModel>>.broadcast();

  DocumentStruct(this._service);

  SupabaseService get service => _service;
  String? get currentUserId => _service.currentUserId;
  String? get currentUserEmail => _service.currentUserEmail;

  /// Stream lắng nghe danh sách tài liệu
  Stream<List<DocumentModel>> get documentsStream =>
      _documentsController.stream;

  /// Lấy danh sách tài liệu từ Supabase
  Future<List<DocumentModel>> fetchDocuments({
    String? query,
    DocumentType? type,
    String? subject,
    List<String>? tags,
    bool onlyShared = false,
  }) async {
    final docs = await _service.getDocuments(
      query: query,
      type: type,
      subject: subject,
      tags: tags,
      onlyShared: onlyShared,
    );
    if (!_documentsController.isClosed) {
      _documentsController.add(docs);
    }
    return docs;
  }

  /// Lấy chi tiết tài liệu theo ID
  Future<DocumentModel?> getById(String id) async {
    return await _service.getDocumentById(id);
  }

  /// Thêm tài liệu mới (có thể đính kèm file tải lên Supabase Storage)
  Future<String> create({
    required String title,
    String description = '',
    required DocumentType type,
    required String subject,
    File? file,
    Uint8List? fileBytes,
    String? customFileName,
    List<String> tags = const [],
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    _validateTitle(title);
    _validateSubject(subject);
    _validateLocation(locationName, latitude, longitude);

    String fileUrl = '';
    String filePath = '';
    String fileName = '';
    int fileSize = 0;

    // Tải file lên Supabase Storage nếu người dùng chọn file
    if (file != null && await file.exists()) {
      final uploadRes = await _service.uploadFile(
        file: file,
        customFileName: customFileName,
      );
      fileUrl = uploadRes['fileUrl'] as String? ?? '';
      filePath = uploadRes['filePath'] as String? ?? '';
      fileName = uploadRes['fileName'] as String? ?? '';
      fileSize = uploadRes['fileSize'] as int? ?? 0;
    } else if (fileBytes != null && fileBytes.isNotEmpty) {
      final uploadRes = await _service.uploadBytes(
        bytes: fileBytes,
        fileName: customFileName ?? 'document',
      );
      fileUrl = uploadRes['fileUrl'] as String? ?? '';
      filePath = uploadRes['filePath'] as String? ?? '';
      fileName = uploadRes['fileName'] as String? ?? '';
      fileSize = uploadRes['fileSize'] as int? ?? 0;
    }

    // Tạo bản ghi trong bảng documents trên Supabase
    final docId = await _service.createDocument(
      title: title,
      description: description,
      type: type,
      subject: subject,
      fileUrl: fileUrl,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      tags: tags,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
    );

    // Cập nhật lại stream
    await fetchDocuments();
    return docId;
  }

  /// Cập nhật tài liệu
  Future<void> update({
    required String id,
    required String title,
    String description = '',
    required DocumentType type,
    required String subject,
    File? newFile,
    Uint8List? newFileBytes,
    String? customFileName,
    List<String> tags = const [],
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    _validateTitle(title);
    _validateSubject(subject);
    _validateLocation(locationName, latitude, longitude);

    String? fileUrl;
    String? filePath;
    String? fileName;
    int? fileSize;

    if (newFile != null && await newFile.exists()) {
      final uploadRes = await _service.uploadFile(
        file: newFile,
        customFileName: customFileName,
      );
      fileUrl = uploadRes['fileUrl'] as String?;
      filePath = uploadRes['filePath'] as String?;
      fileName = uploadRes['fileName'] as String?;
      fileSize = uploadRes['fileSize'] as int?;
    } else if (newFileBytes != null && newFileBytes.isNotEmpty) {
      final uploadRes = await _service.uploadBytes(
        bytes: newFileBytes,
        fileName: customFileName ?? 'document',
      );
      fileUrl = uploadRes['fileUrl'] as String?;
      filePath = uploadRes['filePath'] as String?;
      fileName = uploadRes['fileName'] as String?;
      fileSize = uploadRes['fileSize'] as int?;
    }

    await _service.updateDocument(
      id: id,
      title: title,
      description: description,
      type: type,
      subject: subject,
      fileUrl: fileUrl,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      tags: tags,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
    );

    await fetchDocuments();
  }

  /// Xóa tài liệu (RLS đảm bảo chỉ chủ sở hữu mới xóa được)
  Future<void> deleteById(String id, {String? filePath}) async {
    await _service.deleteDocument(id, filePath: filePath);
    await fetchDocuments();
  }

  // === CHỨC NĂNG CHIA SẺ TÀI LIỆU ===

  /// Chia sẻ tài liệu cho người khác qua email
  Future<void> shareDocument({
    required String documentId,
    required String email,
    String permission = 'view',
  }) async {
    await _service.shareDocument(
      documentId: documentId,
      email: email,
      permission: permission,
    );
  }

  /// Lấy danh sách những người đang được chia sẻ tài liệu
  Future<List<DocumentShareModel>> getShares(String documentId) async {
    return await _service.getDocumentShares(documentId);
  }

  /// Hủy quyền chia sẻ
  Future<void> removeShare(String shareId) async {
    await _service.removeShare(shareId);
  }

  // === VALIDATION ===
  void _validateTitle(String title) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Tiêu đề tài liệu không được để trống');
    }
    if (title.trim().length > 200) {
      throw ArgumentError('Tiêu đề không được vượt quá 200 ký tự');
    }
  }

  void _validateSubject(String subject) {
    if (subject.trim().isEmpty) {
      throw ArgumentError('Môn học không được để trống');
    }
  }

  void _validateLocation(
    String? locationName,
    double? latitude,
    double? longitude,
  ) {
    final error = LocationSelection.validate(
      locationName: locationName ?? '',
      latitude: latitude,
      longitude: longitude,
    );
    if (error != null) throw ArgumentError(error);
  }

  void dispose() {
    _documentsController.close();
  }
}
