import '../modified/models/document_model.dart';
import '../services/supabase/supabase_service.dart';

/// Business logic cho tìm kiếm và lọc tài liệu trên Supabase
class SearchStruct {
  final SupabaseService _service;

  SearchStruct(this._service);

  /// Tìm kiếm tài liệu với các bộ lọc
  Stream<List<DocumentModel>> search({
    String? query,
    DocumentType? type,
    String? subject,
    bool onlyShared = false,
  }) async* {
    final docs = await _service.getDocuments(
      query: query,
      type: type,
      subject: subject,
      onlyShared: onlyShared,
    );
    yield docs;
  }
}
