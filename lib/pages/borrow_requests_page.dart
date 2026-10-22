import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modified/models/borrow_request_model.dart';
import '../services/supabase/borrow_service.dart';
import '../services/supabase/supabase_service.dart';
import '../widgets/framework/app_scaffold.dart';
import 'document_detail_page.dart';

/// Trang quản lý yêu cầu mượn tài liệu học tập
/// Gồm 2 Tab: "Tôi nhận" (Incoming) và "Tôi gửi" (Outgoing)
class BorrowRequestsPage extends StatefulWidget {
  const BorrowRequestsPage({super.key});

  @override
  State<BorrowRequestsPage> createState() => _BorrowRequestsPageState();
}

class _BorrowRequestsPageState extends State<BorrowRequestsPage> {
  bool _isLoading = true;
  List<BorrowRequestModel> _incomingRequests = [];
  List<BorrowRequestModel> _outgoingRequests = [];
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
      if (!mounted) return;
      _loadData();
      _setupRealtime();
      _setupFcm();
    });
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

  void _setupRealtime() {
    try {
      final borrowService = _getBorrowService(context);
      _realtimeChannel = borrowService.subscribeRealtimeNotifications(
        onNewIncomingRequest: (request) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Yêu cầu mượn mới từ ${request.requesterEmail}!',
              ),
              backgroundColor: Colors.indigo,
              action: SnackBarAction(
                label: 'Tải lại',
                textColor: Colors.white,
                onPressed: _loadData,
              ),
            ),
          );
          _loadData();
        },
        onRequestStatusChanged: (request) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Yêu cầu mượn "${request.documentTitle.isNotEmpty ? request.documentTitle : 'tài liệu'}" đã chuyển sang: ${request.statusDisplay}!',
              ),
              backgroundColor: request.isApproved
                  ? Colors.green
                  : Colors.orange,
              action: SnackBarAction(
                label: 'Tải lại',
                textColor: Colors.white,
                onPressed: _loadData,
              ),
            ),
          );
          _loadData();
        },
      );
    } catch (e) {
      debugPrint('Lỗi đăng ký Realtime: $e');
    }
  }

  Future<void> _setupFcm() async {
    try {
      final supabase = context.read<SupabaseService>();
      await BorrowService.setupFcmToken(supabase);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final borrowService = _getBorrowService(context);
      final incoming = await borrowService.getIncoming();
      final outgoing = await borrowService.getOutgoing();

      if (mounted) {
        setState(() {
          _incomingRequests = incoming;
          _outgoingRequests = outgoing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách yêu cầu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleApprove(BorrowRequestModel req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyệt yêu cầu mượn'),
        content: Text(
          'Duyệt cho "${req.requesterEmail}" mượn tài liệu "${req.documentTitle.isNotEmpty ? req.documentTitle : 'này'}"?\n\nNgười mượn sẽ nhận được quyền xem tài liệu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận duyệt'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final borrowService = _getBorrowService(context);
        await borrowService.approve(req);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã duyệt yêu cầu mượn thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi duyệt yêu cầu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject(BorrowRequestModel req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu mượn'),
        content: Text(
          'Bạn có chắc chắn muốn từ chối yêu cầu từ "${req.requesterEmail}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final borrowService = _getBorrowService(context);
        await borrowService.reject(req);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã từ chối yêu cầu mượn')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi từ chối yêu cầu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleMarkReturned(BorrowRequestModel req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đã trả'),
        content: Text(
          'Đánh dấu "${req.requesterEmail}" đã trả tài liệu?\n\nQuyền xem tài liệu của người mượn sẽ được thu hồi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đã trả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final borrowService = _getBorrowService(context);
        await borrowService.markReturned(req);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xác nhận trả tài liệu thành công!'),
              backgroundColor: Colors.blueGrey,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi cập nhật trạng thái đã trả: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'Chờ duyệt';
        icon = Icons.hourglass_top;
        break;
      case 'approved':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'Đã duyệt';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'Từ chối';
        icon = Icons.cancel_outlined;
        break;
      case 'returned':
        bg = Colors.blueGrey.shade100;
        fg = Colors.blueGrey.shade900;
        label = 'Đã trả';
        icon = Icons.assignment_return_outlined;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        label = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            _buildEmptyState(
              icon: Icons.move_to_inbox_outlined,
              title: 'Không có yêu cầu nào',
              subtitle:
                  'Hiện tại chưa có người dùng nào gửi yêu cầu mượn tài liệu của bạn.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _incomingRequests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final req = _incomingRequests[index];
          final docTitle = req.documentTitle.isNotEmpty
              ? req.documentTitle
              : 'Tài liệu #${req.documentId.substring(0, 8)}';

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          docTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(req.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Người mượn: ${req.requesterEmail}',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Thời gian gửi: ${_formatDateTime(req.createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (req.message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Lời nhắn: "${req.message}"',
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  if (req.isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Từ chối'),
                          onPressed: () => _handleReject(req),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Duyệt'),
                          onPressed: () => _handleApprove(req),
                        ),
                      ],
                    ),
                  ],
                  if (req.isApproved) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assignment_return_outlined, size: 16),
                        label: const Text('Đánh dấu đã trả'),
                        onPressed: () => _handleMarkReturned(req),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutgoingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_outgoingRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            _buildEmptyState(
              icon: Icons.outbox_outlined,
              title: 'Chưa có yêu cầu nào',
              subtitle: 'Bạn chưa gửi yêu cầu mượn tài liệu nào đến người khác.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _outgoingRequests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final req = _outgoingRequests[index];
          final docTitle = req.documentTitle.isNotEmpty
              ? req.documentTitle
              : 'Tài liệu #${req.documentId.substring(0, 8)}';

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          docTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(req.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Thời gian gửi: ${_formatDateTime(req.createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (req.message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lời nhắn của bạn: "${req.message}"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  if (req.isApproved) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Chủ tài liệu đã duyệt yêu cầu! Bạn có thể xem tài liệu ngay.',
                              style: TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DocumentDetailPage(
                                    documentId: req.documentId,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Xem'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (req.isRejected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Yêu cầu đã bị chủ tài liệu từ chối.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ],
                  if (req.isReturned) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tài liệu đã được trả.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _incomingRequests.where((r) => r.isPending).length;

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Yêu cầu mượn',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
        body: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.move_to_inbox_outlined),
                      const SizedBox(width: 8),
                      const Text('Tôi nhận'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  icon: Icon(Icons.outbox_outlined),
                  text: 'Tôi gửi',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildIncomingTab(),
                  _buildOutgoingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
