import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase/auth_service.dart';
import '../services/supabase/supabase_service.dart';
import '../struct/document_struct.dart';
import '../modified/models/document_model.dart';
import '../widgets/framework/app_scaffold.dart';
import '../widgets/framework/document_tile.dart';
import '../widgets/framework/recommendation_section.dart';
import '../widgets/framework/search_field.dart';
import '../widgets/util/loading_indicator.dart';
import '../widgets/util/empty_state.dart';
import 'document_form_page.dart';
import 'document_detail_page.dart';
import 'borrow_requests_page.dart';

/// Trang chính - hiển thị danh sách tài liệu từ Supabase, search bar, bộ lọc
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentType? _filterType;
  bool _onlyShared = false;
  String? _selectedTag;
  bool _isLoading = false;
  int _loadVersion = 0;
  List<DocumentModel> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Tải danh sách tài liệu từ Supabase
  Future<void> _loadDocuments() async {
    if (!mounted) return;
    final version = ++_loadVersion;
    setState(() => _isLoading = true);
    try {
      final docStruct = context.read<DocumentStruct>();
      final docs = await docStruct.fetchDocuments(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        type: _filterType,
        onlyShared: _onlyShared,
      );
      if (mounted && version == _loadVersion) {
        setState(() {
          _documents = docs;
        });
      }
    } catch (e) {
      if (mounted && version == _loadVersion) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Mở form thêm tài liệu mới
  Future<void> _openAddDocument() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DocumentFormPage()));
    _loadDocuments();
  }

  /// Mở chi tiết tài liệu
  Future<void> _openDocumentDetail(DocumentModel doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: doc.id)),
    );
    _loadDocuments();
  }

  /// Mở danh sách yêu cầu mượn (cả yêu cầu nhận và gửi)
  Future<void> _openBorrowRequests() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BorrowRequestsPage()));
    _loadDocuments();
  }

  /// Mở dialog chia sẻ tài liệu
  void _openShareDialog(DocumentModel doc) {
    final emailController = TextEditingController();
    String permission = 'view';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.share, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chia sẻ: ${doc.title}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập email người dùng bạn muốn chia sẻ:'),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email người nhận',
                  hintText: 'nguoinhan@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
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
                          documentId: doc.id,
                          email: email,
                          permission: permission,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã chia sẻ cho $email')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi chia sẻ: $e'),
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

  /// Xác nhận và xóa tài liệu
  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${doc.title}" khỏi Supabase?'),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Đã xóa "${doc.title}"')));
        }
        _loadDocuments();
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

  /// Đăng xuất tài khoản
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userEmail = authService.currentUserEmail ?? 'Người dùng';
    final currentUid = authService.currentUserId;

    return AppScaffold(
      title: 'StudyDocs',
      actions: [
        IconButton(
          icon: const Icon(Icons.inbox_outlined),
          tooltip: 'Yêu cầu mượn',
          onPressed: _openBorrowRequests,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Làm mới',
          onPressed: _loadDocuments,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          tooltip: 'Tài khoản',
          onSelected: (value) {
            if (value == 'logout') _signOut();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                userEmail,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDocument,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tài liệu'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final contentWidth = isWide
                ? constraints.maxWidth.clamp(0.0, 1100.0)
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    // Ô tìm kiếm
                    SearchField(
                      controller: _searchController,
                      onChanged: (value) {
                        _searchQuery = value;
                        _loadDocuments();
                      },
                      onClear: () {
                        _searchQuery = '';
                        _loadDocuments();
                      },
                    ),

                    // Bộ lọc chia sẻ và loại tài liệu
                    _buildFilterChips(),

                    // Lọc theo tag trong các tài liệu đã tải theo bộ lọc hiện tại
                    _buildTagFilterChips(),

                    // Gợi ý tài liệu theo tag/môn/loại đã quan tâm
                    RecommendationSection(
                      service: context.read<SupabaseService>(),
                      onDocumentTap: _openDocumentDetail,
                    ),

                    const Divider(height: 1),

                    // Danh sách tài liệu
                    Expanded(
                      child: _isLoading
                          ? const LoadingIndicator(
                              message: 'Đang tải từ Supabase...',
                            )
                          : _visibleDocuments.isEmpty
                          ? EmptyState(
                              icon: Icons.description_outlined,
                              title:
                                  _searchQuery.isNotEmpty ||
                                      _filterType != null ||
                                      _onlyShared ||
                                      _selectedTag != null
                                  ? 'Không tìm thấy tài liệu phù hợp'
                                  : 'Chưa có tài liệu nào',
                              subtitle:
                                  _onlyShared &&
                                      _searchQuery.isEmpty &&
                                      _filterType == null &&
                                      _selectedTag == null
                                  ? 'Chưa có ai chia sẻ tài liệu cho bạn'
                                  : 'Bấm nút "Thêm tài liệu" để tải tệp lên Supabase Storage',
                              action: !_onlyShared
                                  ? FilledButton.icon(
                                      onPressed: _openAddDocument,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Thêm tài liệu'),
                                    )
                                  : null,
                            )
                          : isWide
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: contentWidth >= 1000
                                        ? 3
                                        : 2,
                                    mainAxisExtent: 190,
                                  ),
                              itemCount: _visibleDocuments.length,
                              itemBuilder: (context, index) {
                                final doc = _visibleDocuments[index];
                                return _buildDocumentTile(doc, currentUid);
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 80,
                              ),
                              itemCount: _visibleDocuments.length,
                              itemBuilder: (context, index) {
                                final doc = _visibleDocuments[index];
                                return _buildDocumentTile(doc, currentUid);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentTile(DocumentModel doc, String? currentUid) {
    return DocumentTile(
      document: doc,
      currentUserId: currentUid,
      onTap: () => _openDocumentDetail(doc),
      onDelete: doc.isOwner(currentUid) ? () => _confirmDelete(doc) : null,
      onShare: doc.isOwner(currentUid) ? () => _openShareDialog(doc) : null,
    );
  }

  List<DocumentModel> get _visibleDocuments {
    final selectedTag = _selectedTag;
    if (selectedTag == null) return _documents;
    return _documents
        .where((document) => document.tags.contains(selectedTag))
        .toList();
  }

  /// Chips lọc theo sở hữu và loại tài liệu
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Lọc: Tất cả
            FilterChip(
              selected:
                  !_onlyShared && _filterType == null && _selectedTag == null,
              label: const Text('Tất cả'),
              onSelected: (_) {
                setState(() {
                  _onlyShared = false;
                  _filterType = null;
                  _selectedTag = null;
                });
                _loadDocuments();
              },
            ),
            const SizedBox(width: 8),

            // Lọc: Được chia sẻ với tôi
            FilterChip(
              selected: _onlyShared,
              avatar: const Icon(Icons.people_outline, size: 16),
              label: const Text('Được chia sẻ'),
              onSelected: (val) {
                setState(() {
                  _onlyShared = val;
                });
                _loadDocuments();
              },
            ),
            const SizedBox(width: 8),

            // Lọc theo loại
            ...DocumentType.values.map(
              (type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: _filterType == type,
                  label: Text(type.displayName),
                  onSelected: (_) {
                    setState(() {
                      _filterType = _filterType == type ? null : type;
                    });
                    _loadDocuments();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilterChips() {
    final tags = _documents.expand((document) => document.tags).toSet();
    final selectedTag = _selectedTag;
    if (selectedTag != null) tags.add(selectedTag);
    final sortedTags = tags.toList()..sort();
    if (sortedTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Tag:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilterChip(
              selected: _selectedTag == null,
              label: const Text('Tất cả'),
              onSelected: (_) => setState(() => _selectedTag = null),
            ),
            const SizedBox(width: 8),
            ...sortedTags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: _selectedTag == tag,
                  label: Text(tag),
                  onSelected: (_) {
                    setState(() {
                      _selectedTag = _selectedTag == tag ? null : tag;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
