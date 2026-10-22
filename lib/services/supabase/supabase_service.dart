import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modified/models/document_model.dart';
import '../../modified/models/document_share_model.dart';
import 'supabase_config.dart';

/// Dịch vụ kết nối và thao tác với Supabase (Database & Storage).
/// Xác thực (Authentication) do Firebase Auth quản lý.
class SupabaseService {
  final SupabaseClient _client;
  final fb.FirebaseAuth _auth;

  SupabaseService({SupabaseClient? client, fb.FirebaseAuth? auth})
    : _client = client ?? Supabase.instance.client,
      _auth = auth ?? fb.FirebaseAuth.instance;

  SupabaseClient get client => _client;

  // ===========================================================================
  // 1. THÔNG TIN NGƯỜI DÙNG (TỪ FIREBASE AUTH)
  // ===========================================================================

  fb.User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Tạo/cập nhật hồ sơ sau khi đăng nhập (id = Firebase UID).
  Future<void> ensureProfile({
    required String uid,
    required String email,
    String fullName = '',
  }) async {
    final data = <String, dynamic>{'id': uid, 'email': email};
    if (fullName.trim().isNotEmpty) {
      data['full_name'] = fullName.trim();
    }
    await _client.from('profiles').upsert(data, onConflict: 'id');
  }

  /// Lấy hồ sơ người dùng, null nếu chưa có.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<void> updateInterests(String uid, List<String> interests) async {
    await _client
        .from('profiles')
        .update({'interests': interests})
        .eq('id', uid);
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    await _client.from('profiles').update({'fcm_token': token}).eq('id', uid);
  }

  // ===========================================================================
  // 2. SUPABASE STORAGE (LƯU TRỮ TỆP TIN TRÊN CLOUD)
  // ===========================================================================

  /// Tải dữ liệu byte lên Supabase Storage (Hỗ trợ Web, Mobile & Desktop)
  Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final uniquePath =
        '${currentUserId ?? 'general'}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    // Xác định content-type cơ bản dựa trên phần mở rộng file
    final ext = p.extension(sanitizedName).toLowerCase();
    String? contentType;
    if (ext == '.pdf') {
      contentType = 'application/pdf';
    } else if (ext == '.png') {
      contentType = 'image/png';
    } else if (ext == '.jpg' || ext == '.jpeg') {
      contentType = 'image/jpeg';
    } else if (ext == '.doc') {
      contentType = 'application/msword';
    } else if (ext == '.docx') {
      contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    } else if (ext == '.txt') {
      contentType = 'text/plain';
    }

    await _client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          uniquePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    final fileUrl = _client.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl(uniquePath);

    return {
      'fileUrl': fileUrl,
      'filePath': uniquePath,
      'fileName': fileName,
      'fileSize': bytes.length,
    };
  }

  /// Tải tệp tin (File) từ thiết bị lên Supabase Storage
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    String? customFileName,
  }) async {
    final originalName = customFileName ?? p.basename(file.path);
    final bytes = await file.readAsBytes();
    return await uploadBytes(bytes: bytes, fileName: originalName);
  }

  /// Xóa file trên Storage
  Future<void> deleteStorageFile(String filePath) async {
    if (filePath.isEmpty) return;
    try {
      await _client.storage.from(SupabaseConfig.storageBucket).remove([
        filePath,
      ]);
    } catch (_) {
      // Bỏ qua nếu file đã bị xóa
    }
  }

  // ===========================================================================
  // 3. TÀI LIỆU (DOCUMENTS - POSTGRES DB)
  // ===========================================================================

  /// Lấy danh sách tài liệu (RLS tự động lọc tài liệu của tôi và được chia sẻ)
  Future<List<DocumentModel>> getDocuments({
    String? query,
    DocumentType? type,
    String? subject,
    List<String>? tags,
    bool onlyShared = false,
  }) async {
    final myEmail = currentUserEmail?.toLowerCase();
    final myUid = currentUserId;

    var request = _client.from('documents').select('''
      *,
      document_shares(shared_with_email, permission)
    ''');

    if (type != null) {
      request = request.eq('type', type.name);
    }
    if (subject != null && subject.trim().isNotEmpty) {
      request = request.eq('subject', subject.trim());
    }
    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('title', '%${query.trim()}%');
    }
    if (tags != null && tags.isNotEmpty) {
      request = request.contains('tags', tags);
    }

    final response = await request.order('updated_at', ascending: false);
    final List<dynamic> data = response;

    final documents = <DocumentModel>[];
    for (final item in data) {
      final map = Map<String, dynamic>.from(item as Map);
      final ownerId = map['owner_id']?.toString() ?? '';
      final shares = (map['document_shares'] as List?) ?? [];

      String? sharedPermission;
      if (ownerId != myUid && myEmail != null) {
        // Tìm quyền chia sẻ cho email của tôi
        for (final s in shares) {
          final sEmail = s['shared_with_email']?.toString().toLowerCase();
          if (sEmail == myEmail) {
            sharedPermission = s['permission']?.toString() ?? 'view';
            break;
          }
        }
      }

      // Chỉ hiển thị tài liệu của chính mình hoặc được chia sẻ cho email của mình
      final isSharedToMe = sharedPermission != null;
      if (ownerId != myUid && !isSharedToMe) {
        continue;
      }

      // Nếu người dùng chọn tab "Chỉ tài liệu được chia sẻ"
      if (onlyShared && ownerId == myUid) {
        continue;
      }

      documents.add(
        DocumentModel.fromMap(map, sharedPermission: sharedPermission),
      );
    }

    return documents;
  }

  /// Lấy chi tiết một tài liệu theo ID
  Future<DocumentModel?> getDocumentById(String id) async {
    final myEmail = currentUserEmail?.toLowerCase();
    final myUid = currentUserId;

    final response = await _client
        .from('documents')
        .select('''
      *,
      document_shares(shared_with_email, permission)
    ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    final map = Map<String, dynamic>.from(response);
    final ownerId = map['owner_id']?.toString() ?? '';
    final shares = (map['document_shares'] as List?) ?? [];

    String? sharedPermission;
    if (ownerId != myUid && myEmail != null) {
      for (final s in shares) {
        if (s['shared_with_email']?.toString().toLowerCase() == myEmail) {
          sharedPermission = s['permission']?.toString() ?? 'view';
          break;
        }
      }
    }

    return DocumentModel.fromMap(map, sharedPermission: sharedPermission);
  }

  /// Thêm tài liệu mới vào Supabase
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
    final uid = currentUserId;
    if (uid == null) throw StateError('Vui lòng đăng nhập');

    final insertMap = {
      'title': title.trim(),
      'description': description.trim(),
      'type': type.name,
      'subject': subject.trim(),
      'file_url': fileUrl,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'owner_id': uid,
      'owner_email': currentUserEmail ?? '',
      'tags': tags,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final result = await _client
        .from('documents')
        .insert(insertMap)
        .select('id')
        .single();

    return result['id'].toString();
  }

  /// Cập nhật tài liệu (RLS kiểm tra quyền chủ sở hữu hoặc 'edit')
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
  }) async {
    final updateMap = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type.name,
      'subject': subject.trim(),
      'tags': tags,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (fileUrl != null) updateMap['file_url'] = fileUrl;
    if (filePath != null) updateMap['file_path'] = filePath;
    if (fileName != null) updateMap['file_name'] = fileName;
    if (fileSize != null) updateMap['file_size'] = fileSize;

    await _client.from('documents').update(updateMap).eq('id', id);
  }

  /// Xóa tài liệu (RLS đảm bảo chỉ chủ sở hữu mới xóa được)
  Future<void> deleteDocument(String id, {String? filePath}) async {
    if (filePath != null && filePath.isNotEmpty) {
      await deleteStorageFile(filePath);
    }
    await _client.from('documents').delete().eq('id', id);
  }

  // ===========================================================================
  // 4. QUYỀN CHIA SẺ (DOCUMENT SHARES)
  // ===========================================================================

  /// Lấy danh sách các tài khoản được chia sẻ tài liệu này
  Future<List<DocumentShareModel>> getDocumentShares(String documentId) async {
    final response = await _client
        .from('document_shares')
        .select()
        .eq('document_id', documentId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    return data
        .map(
          (e) =>
              DocumentShareModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Chia sẻ tài liệu cho người dùng khác qua Email
  Future<void> shareDocument({
    required String documentId,
    required String email,
    String permission = 'view', // 'view' hoặc 'edit'
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail == currentUserEmail?.toLowerCase()) {
      throw ArgumentError('Không thể chia sẻ tài liệu cho chính mình.');
    }

    await _client.from('document_shares').upsert({
      'document_id': documentId,
      'shared_with_email': cleanEmail,
      'permission': permission,
    }, onConflict: 'document_id,shared_with_email');
  }

  /// Thu hồi quyền chia sẻ
  Future<void> removeShare(String shareId) async {
    await _client.from('document_shares').delete().eq('id', shareId);
  }
}
