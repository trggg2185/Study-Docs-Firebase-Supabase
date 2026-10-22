import '../modified/models/document_model.dart';
import '../services/supabase/supabase_service.dart';

class RecommendationStruct {
  final SupabaseService _service;

  RecommendationStruct(this._service);

  Future<List<DocumentModel>> suggest({int limit = 6}) async {
    if (limit <= 0) return [];

    final documents = await _service.getDocuments();
    final currentUserId = _service.currentUserId;
    final ownedDocuments = documents
        .where((document) => document.isOwner(currentUserId))
        .toList();

    final tagWeights = <String, int>{};
    final subjects = <String>{};
    final types = <DocumentType>{};

    for (final document in ownedDocuments) {
      final normalizedSubject = document.subject.trim().toLowerCase();
      if (normalizedSubject.isNotEmpty) subjects.add(normalizedSubject);
      types.add(document.type);

      for (final tag in _tagsFrom(document)) {
        tagWeights.update(
          tag,
          (weight) => weight < 3 ? weight + 1 : weight,
          ifAbsent: () => 1,
        );
      }
    }

    final ranked =
        documents
            .where((document) => !document.isOwner(currentUserId))
            .map(
              (document) => (
                document: document,
                score: score(
                  document,
                  tagWeights: tagWeights,
                  subjects: subjects,
                  types: types,
                  candidateTags: _tagsFrom(document),
                ),
              ),
            )
            .where((entry) => entry.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return ranked.take(limit).map((entry) => entry.document).toList();
  }

  static double score(
    DocumentModel candidate, {
    required Map<String, int> tagWeights,
    required Set<String> subjects,
    required Set<DocumentType> types,
    List<String> candidateTags = const [],
  }) {
    var result = 0;
    final normalizedTags = candidateTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();

    for (final tag in normalizedTags) {
      final weight = tagWeights[tag] ?? 0;
      result += 3 * weight.clamp(0, 3).toInt();
    }

    if (subjects.contains(candidate.subject.trim().toLowerCase())) result += 2;
    if (types.contains(candidate.type)) result += 1;
    return result.toDouble();
  }

  static List<String> _tagsFrom(DocumentModel document) {
    final rawTags = document.toMap()['tags'];
    if (rawTags is! List) return const [];
    return rawTags.whereType<String>().toList();
  }
}
