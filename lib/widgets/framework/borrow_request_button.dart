import 'package:flutter/material.dart';

import '../../modified/models/document_model.dart';

/// Nút gửi yêu cầu mượn tài liệu (chỉ hiện với tài liệu không phải của mình).
/// TODO(dai): thay stub bằng trạng thái yêu cầu + dialog gửi lời nhắn.
class BorrowRequestButton extends StatelessWidget {
  final DocumentModel document;

  const BorrowRequestButton({super.key, required this.document});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
