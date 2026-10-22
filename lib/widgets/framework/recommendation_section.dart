import 'package:flutter/material.dart';

import '../../modified/models/document_model.dart';
import '../../services/supabase/supabase_service.dart';
import '../../struct/recommendation_struct.dart';

class RecommendationSection extends StatefulWidget {
  final SupabaseService service;
  final ValueChanged<DocumentModel>? onDocumentTap;

  const RecommendationSection({
    super.key,
    required this.service,
    this.onDocumentTap,
  });

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  late Future<List<DocumentModel>> _suggestions;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(covariant RecommendationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _loadSuggestions();
  }

  void _loadSuggestions() {
    _suggestions = RecommendationStruct(widget.service).suggest();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentModel>>(
      future: _suggestions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Không tải được gợi ý tài liệu.')),
                IconButton(
                  tooltip: 'Thử lại',
                  onPressed: () => setState(_loadSuggestions),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final documents = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gợi ý cho bạn',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Thử lại',
                  onPressed: () => setState(_loadSuggestions),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final tags = _tagsFrom(document);
                  return SizedBox(
                    width: 220,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onDocumentTap?.call(document),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                document.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (tags.isNotEmpty)
                                Text(
                                  tags.take(2).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              const Spacer(),
                              Text(
                                'Gợi ý dựa trên tài liệu bạn quan tâm',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _tagsFrom(DocumentModel document) {
    final tags = document.toMap()['tags'];
    if (tags is! List) return const [];
    return tags.whereType<String>().toList();
  }
}
