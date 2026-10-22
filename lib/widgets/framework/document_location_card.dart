import 'package:flutter/material.dart';

import '../../modified/models/document_model.dart';

/// Card hiển thị vị trí vật lý của tài liệu trong trang chi tiết.
/// TODO(duc): thay stub bằng tên vị trí + mini-map + nút mở bản đồ.
class DocumentLocationCard extends StatelessWidget {
  final DocumentModel document;

  const DocumentLocationCard({super.key, required this.document});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
