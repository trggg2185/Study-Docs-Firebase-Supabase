import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modified/models/borrow_request_model.dart';
import '../../modified/models/document_model.dart';
import '../../pages/borrow_requests_page.dart';
import '../../services/supabase/borrow_service.dart';
import '../../services/supabase/supabase_service.dart';

/// Nút gửi yêu cầu mượn tài liệu (chỉ hiện với tài liệu không phải của mình).
/// Quản lý các trạng thái: Chưa yêu cầu -> Đang chờ duyệt -> Đã duyệt.
class BorrowRequestButton extends StatefulWidget {
  final DocumentModel document;

  const BorrowRequestButton({super.key, required this.document});

  @override
  State<BorrowRequestButton> createState() => _BorrowRequestButtonState();
}

class _BorrowRequestButtonState extends State<BorrowRequestButton> {
  BorrowRequestModel? _currentRequest;
  bool _isLoading = true;
  bool _isSubmitting = false;
  RealtimeChannel? _realtimeChannel;

  BorrowService _getBorrowService(BuildContext context) {
    try {
      return context.read<BorrowService>();
    } catch (_) {
      final supabase = context.read<SupabaseService>();
      return BorrowService(supabase);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequestStatus();
      _setupRealtimeSubscription();
    });
  }

  @override
  void didUpdateWidget(covariant BorrowRequestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _loadRequestStatus();
    }
  }

  @override
  void dispose() {
    _cleanupRealtime();
    super.dispose();
  }

  void _cleanupRealtime() {
    if (_realtimeChannel != null && mounted) {
      try {
        _getBorrowService(context).unsubscribeRealtime(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
  }

  void _setupRealtimeSubscription() {
    try {
      final borrowService = _getBorrowService(context);
      _realtimeChannel = borrowService.subscribeRealtimeNotifications(
        onRequestStatusChanged: (req) {
          if (!mounted) return;
          if (req.documentId == widget.document.id) {
            setState(() {
              _currentRequest = req.isReturned || req.isRejected ? null : req;
            });
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _loadRequestStatus() async {
    final supabase = context.read<SupabaseService>();
    final currentUid = supabase.currentUserId;

    if (currentUid == null || widget.document.isOwner(currentUid)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentRequest = null;
        });
      }
      return;
    }

    try {
      final borrowService = _getBorrowService(context);
      final req = await borrowService.getOpenRequest(widget.document.id);
      if (mounted) {
        setState(() {
          _currentRequest = req;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openRequestDialog() async {
    final messageController = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.handshake_outlined, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Yêu cầu mượn tài liệu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tài liệu: ${widget.document.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Lời nhắn gửi đến chủ tài liệu (tùy chọn):'),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Mình muốn mượn ôn thi cuối kỳ môn này...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Gửi yêu cầu'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldSend == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        final borrowService = _getBorrowService(context);
        await borrowService.request(
          document: widget.document,
          message: messageController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi yêu cầu mượn tài liệu thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadRequestStatus();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể gửi yêu cầu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  void _navigateToBorrowPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BorrowRequestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = context.watch<SupabaseService>();
    final currentUid = supabase.currentUserId;

    // Không hiển thị nếu là tài liệu của chính mình
    if (currentUid != null && widget.document.isOwner(currentUid)) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    Widget actionButton;

    if (_currentRequest == null) {
      // 1. Chưa gửi yêu cầu
      actionButton = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.handshake_outlined),
        label: Text(_isSubmitting ? 'Đang gửi...' : 'Yêu cầu mượn'),
        onPressed: _isSubmitting ? null : _openRequestDialog,
      );
    } else if (_currentRequest!.isPending) {
      // 2. Đang chờ duyệt (disable)
      actionButton = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange.shade800,
          side: BorderSide(color: Colors.orange.shade400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.hourglass_top, size: 18),
        label: const Text('Đang chờ duyệt'),
        onPressed: null, // Disable
      );
    } else if (_currentRequest!.isApproved) {
      // 3. Đã được duyệt
      actionButton = FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade100,
          foregroundColor: Colors.green.shade900,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
        label: const Text('Đã được duyệt'),
        onPressed: _navigateToBorrowPage,
      );
    } else {
      // 4. Đã trả hoặc bị từ chối trước đó -> cho phép yêu cầu lại
      actionButton = FilledButton.icon(
        icon: const Icon(Icons.handshake_outlined),
        label: const Text('Yêu cầu mượn lại'),
        onPressed: _openRequestDialog,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actionButton,
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.format_list_bulleted, size: 16),
            label: const Text(
              'Danh sách yêu cầu mượn',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: _navigateToBorrowPage,
          ),
        ),
      ],
    );
  }
}
