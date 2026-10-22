import 'package:flutter/material.dart';

import '../../modified/models/document_model.dart';

/// Widget hiển thị một tài liệu trong danh sách
class DocumentTile extends StatelessWidget {
  final DocumentModel document;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const DocumentTile({
    super.key,
    required this.document,
    this.currentUserId,
    this.onTap,
    this.onDelete,
    this.onShare,
  });

  IconData _getTypeIcon() {
    switch (document.type) {
      case DocumentType.lecture:
        return Icons.school;
      case DocumentType.exercise:
        return Icons.assignment;
      case DocumentType.reference:
        return Icons.menu_book;
    }
  }

  Color _getTypeColor() {
    switch (document.type) {
      case DocumentType.lecture:
        return Colors.blue;
      case DocumentType.exercise:
        return Colors.orange;
      case DocumentType.reference:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor();
    final isMyDoc = document.isOwner(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_getTypeIcon(), color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                document.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (document.fileUrl.isNotEmpty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.cloud_done, size: 16, color: Colors.blueGrey),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              document.subject,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // Badge loại tài liệu
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    document.type.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Badge quyền sở hữu hoặc được chia sẻ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isMyDoc
                        ? Colors.indigo.withValues(alpha: 0.08)
                        : Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isMyDoc
                        ? 'Của tôi'
                        : (document.sharedPermission == 'edit'
                              ? 'Chia sẻ (Sửa)'
                              : 'Được chia sẻ'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMyDoc ? Colors.indigo : Colors.teal.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Ngày cập nhật
                Text(
                  _formatDate(document.updatedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (document.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: document.tags.take(3).map((tag) {
                  return Chip(
                    label: Text(tag),
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            if (value == 'share') onShare?.call();
            if (value == 'delete') onDelete?.call();
          },
          itemBuilder: (context) => [
            if (isMyDoc)
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Chia sẻ'),
                  ],
                ),
              ),
            if (isMyDoc && onDelete != null)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa tài liệu', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
