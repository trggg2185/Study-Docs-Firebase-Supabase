import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../struct/document_struct.dart';
import '../services/supabase/supabase_service.dart';
import '../modified/models/document_model.dart';
import '../modified/models/document_share_model.dart';
import '../widgets/framework/app_scaffold.dart';
import '../widgets/framework/borrow_request_button.dart';
import '../widgets/framework/document_location_card.dart';
import '../widgets/util/loading_indicator.dart';
import 'document_form_page.dart';

/// Trang chi tiết tài liệu - xem thông tin, tải file Supabase Storage, và quản lý chia sẻ
class DocumentDetailPage extends StatefulWidget {
  final String documentId;

  const DocumentDetailPage({super.key, required this.documentId});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  List<DocumentShareModel> _shares = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final docStruct = context.read<DocumentStruct>();
      final supabaseService = context.read<SupabaseService>();
      final doc = await docStruct.getById(widget.documentId);
      List<DocumentShareModel> shares = [];

      final currentUid = supabaseService.currentUserId;
      if (doc != null && doc.isOwner(currentUid)) {
        shares = await docStruct.getShares(doc.id);
      }

      if (mounted) {
        setState(() {
          _document = doc;
          _shares = shares;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mở liên kết tải file trên trình duyệt
  Future<void> _openFileUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết này')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi mở file: $e')));
      }
    }
  }

  /// Mở dialog thêm người chia sẻ
  void _openAddShareDialog() {
    final emailController = TextEditingController();
    String permission = 'view';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chia sẻ tài liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập email người nhận:'),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Quyền truy cập:'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'view',
                    label: Text('Chỉ xem'),
                    icon: Icon(Icons.visibility),
                  ),
                  ButtonSegment(
                    value: 'edit',
                    label: Text('Được sửa'),
                    icon: Icon(Icons.edit),
                  ),
                ],
                selected: {permission},
                onSelectionChanged: (set) {
                  setDialogState(() => permission = set.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập email hợp lệ'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await context.read<DocumentStruct>().shareDocument(
                          documentId: widget.documentId,
                          email: email,
                          permission: permission,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã chia sẻ cho $email')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Chia sẻ'),
            ),
          ],
        ),
      ),
    );
  }

  /// Xóa quyền chia sẻ
  Future<void> _removeShare(DocumentShareModel share) async {
    try {
      await context.read<DocumentStruct>().removeShare(share.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thu hồi chia sẻ với ${share.sharedWithEmail}'),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thu hồi chia sẻ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Xác nhận xóa tài liệu
  Future<void> _confirmDelete() async {
    final doc = _document;
    if (doc == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text(
          'Bạn có chắc muốn xóa "${doc.title}"?\n\nTệp tin trên Supabase Storage cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<DocumentStruct>().deleteById(
          doc.id,
          filePath: doc.filePath,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Đã xóa "${doc.title}"')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể xóa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Chi tiết tài liệu',
        body: LoadingIndicator(message: 'Đang tải dữ liệu...'),
      );
    }

    final doc = _document;
    if (doc == null) {
      return AppScaffold(
        title: 'Chi tiết',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Tài liệu không tồn tại hoặc bạn không có quyền truy cập.',
              ),
            ],
          ),
        ),
      );
    }

    final currentUid = context.read<SupabaseService>().currentUserId;
    final isOwner = doc.isOwner(currentUid);
    final canEdit = doc.canEdit(currentUid);

    return AppScaffold(
      title: 'Chi tiết tài liệu',
      actions: [
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Sửa tài liệu',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DocumentFormPage(documentId: doc.id),
                ),
              );
              _loadData();
            },
          ),
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Xóa tài liệu',
            onPressed: _confirmDelete,
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tiêu đề
                Text(
                  doc.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Badge loại và quyền
                Row(
                  children: [
                    _buildTypeBadge(doc.type),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isOwner
                            ? 'Tài liệu của tôi'
                            : (doc.sharedPermission == 'edit'
                                  ? 'Được chia sẻ (Quyền sửa)'
                                  : 'Được chia sẻ (Chỉ xem)'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOwner ? Colors.indigo : Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Card thông tin
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow(
                          context,
                          Icons.subject,
                          'Môn học',
                          doc.subject,
                        ),
                        const Divider(),
                        _infoRow(
                          context,
                          Icons.person_outline,
                          'Người tạo',
                          doc.ownerEmail.isNotEmpty
                              ? doc.ownerEmail
                              : '(Không rõ)',
                        ),
                        const Divider(),
                        _infoRow(
                          context,
                          Icons.calendar_today,
                          'Ngày tạo',
                          _formatDate(doc.createdAt),
                        ),
                        const Divider(),
                        _infoRow(
                          context,
                          Icons.update,
                          'Cập nhật',
                          _formatDate(doc.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (doc.tags.isNotEmpty) ...[
                  Text(
                    'Tag',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: doc.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vị trí vật lý
                if (doc.hasLocation ||
                    (doc.locationName?.trim().isNotEmpty ?? false)) ...[
                  DocumentLocationCard(
                    locationName: doc.locationName,
                    latitude: doc.latitude,
                    longitude: doc.longitude,
                  ),
                  const SizedBox(height: 16),
                ],

                // Card tệp tin Supabase Storage
                if (doc.fileUrl.isNotEmpty) ...[
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_done,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc.fileName.isNotEmpty
                                      ? doc.fileName
                                      : 'Tệp tài liệu đính kèm',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _openFileUrl(doc.fileUrl),
                                  icon: const Icon(Icons.open_in_browser),
                                  label: const Text('Mở / Tải tệp từ Supabase'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Sao chép link tải',
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: doc.fileUrl),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã sao chép link file vào clipboard!',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mô tả
                if (doc.description.isNotEmpty) ...[
                  Text(
                    'Mô tả tài liệu',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        doc.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Yêu cầu mượn tài liệu
                if (!isOwner) ...[
                  BorrowRequestButton(document: doc),
                  const SizedBox(height: 16),
                ],

                // Khu vực quản lý chia sẻ (Chỉ hiển thị cho chủ sở hữu)
                if (isOwner) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chia sẻ với người khác (${_shares.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _openAddShareDialog,
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Thêm người nhận'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_shares.isEmpty)
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Chưa chia sẻ cho ai. Bấm "Thêm người nhận" để chia sẻ qua email.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._shares.map(
                      (share) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            radius: 16,
                            child: Icon(Icons.person, size: 18),
                          ),
                          title: Text(
                            share.sharedWithEmail,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            share.permission == 'edit'
                                ? 'Quyền: Được sửa'
                                : 'Quyền: Chỉ xem',
                            style: TextStyle(
                              color: share.permission == 'edit'
                                  ? Colors.orange.shade800
                                  : Colors.blueGrey,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Thu hồi quyền chia sẻ',
                            onPressed: () => _removeShare(share),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(DocumentType type) {
    Color color;
    IconData icon;
    switch (type) {
      case DocumentType.lecture:
        color = Colors.blue;
        icon = Icons.school;
        break;
      case DocumentType.exercise:
        color = Colors.orange;
        icon = Icons.assignment;
        break;
      case DocumentType.reference:
        color = Colors.green;
        icon = Icons.menu_book;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            type.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
