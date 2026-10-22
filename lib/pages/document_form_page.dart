import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../struct/document_struct.dart';
import '../modified/models/document_model.dart';
import '../utils/tag_utils.dart';
import '../widgets/framework/app_scaffold.dart';
import '../widgets/framework/location_field.dart';

/// Trang Thêm / Chỉnh sửa tài liệu (Lưu trên Supabase Database & Storage)
class DocumentFormPage extends StatefulWidget {
  final String? documentId; // null = thêm mới, có giá trị = sửa

  const DocumentFormPage({super.key, this.documentId});

  bool get isEditing => documentId != null;

  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _tagsController = TextEditingController();

  DocumentType _selectedType = DocumentType.lecture;
  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _existingFileUrl = '';
  String _existingFileName = '';
  String _locationName = '';
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _isInitializing = true;
      _loadDocument();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// Tải thông tin tài liệu khi ở chế độ chỉnh sửa
  Future<void> _loadDocument() async {
    if (!widget.isEditing || _isInitialized) return;

    try {
      final doc = await context.read<DocumentStruct>().getById(
        widget.documentId!,
      );
      if (!mounted) return;
      if (doc == null) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy tài liệu hoặc bạn không có quyền.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        _titleController.text = doc.title;
        _descriptionController.text = doc.description;
        _subjectController.text = doc.subject;
        _tagsController.text = doc.tags.join(', ');
        _selectedType = doc.type;
        _existingFileUrl = doc.fileUrl;
        _existingFileName = doc.fileName;
        _locationName = doc.locationName ?? '';
        _latitude = doc.latitude;
        _longitude = doc.longitude;
        _isInitialized = true;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isInitializing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải tài liệu: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  /// Mở bộ chọn tệp tin từ thiết bị để đính kèm lên Supabase Storage
  Future<void> _pickFile() async {
    try {
      // SỬA LẠI: FilePicker.pickFiles() giờ trả về List<PlatformFile>
      final result = await FilePicker.pickFiles(type: FileType.any);

      if (result.isNotEmpty) {
        // SỬA LẠI: result là List<PlatformFile>, lấy phần tử đầu tiên
        final picked = result.first;

        // SỬA LẠI: Dùng phương thức readAsBytes() mới để lấy dữ liệu
        final fileBytes = await picked.readAsBytes();

        setState(() {
          _selectedFileName = picked.name;
          _selectedFileBytes = fileBytes;
          if (!kIsWeb && picked.path != null) {
            _selectedFile = File(picked.path!);
          } else {
            _selectedFile = null;
          }

          // Tự động gợi ý tiêu đề nếu người dùng chưa nhập
          if (_titleController.text.trim().isEmpty) {
            final nameOnly = picked.name.contains('.')
                ? picked.name.substring(0, picked.name.lastIndexOf('.'))
                : picked.name;
            _titleController.text = nameOnly;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã chọn file: ${picked.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Lưu tài liệu (thêm mới hoặc cập nhật lên Supabase)
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final docStruct = context.read<DocumentStruct>();

      if (widget.isEditing) {
        // Cập nhật tài liệu
        await docStruct.update(
          id: widget.documentId!,
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          subject: _subjectController.text,
          tags: normalizeTags(_tagsController.text),
          newFile: _selectedFile,
          newFileBytes: _selectedFileBytes,
          customFileName: _selectedFileName,
          locationName: _locationName.trim().isEmpty
              ? null
              : _locationName.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );
      } else {
        // Tạo mới tài liệu và tải file lên Supabase Storage
        await docStruct.create(
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          subject: _subjectController.text,
          tags: normalizeTags(_tagsController.text),
          file: _selectedFile,
          fileBytes: _selectedFileBytes,
          customFileName: _selectedFileName,
          locationName: _locationName.trim().isEmpty
              ? null
              : _locationName.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Đã cập nhật tài liệu trên Supabase'
                  : 'Đã thêm tài liệu mới lên Supabase',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.isEditing ? 'Sửa tài liệu' : 'Thêm tài liệu mới',
      actions: [
        IconButton(
          onPressed: (_isLoading || _isInitializing) ? null : _save,
          icon: const Icon(Icons.check),
          tooltip: 'Lưu',
        ),
      ],
      body: (_isLoading || _isInitializing)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isInitializing
                        ? 'Đang tải tài liệu...'
                        : 'Đang lưu tài liệu lên Supabase...',
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Tiêu đề
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề tài liệu *',
                          hintText: 'Nhập tiêu đề...',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tiêu đề';
                          }
                          if (value.trim().length > 200) {
                            return 'Tiêu đề không được quá 200 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Môn học
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Môn học *',
                          hintText: 'VD: Lập trình di động, Toán cao cấp...',
                          prefixIcon: Icon(Icons.subject),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập môn học';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tag',
                          hintText: 'Ví dụ: flutter, lập trình, mobile',
                          helperText: 'Cách nhau bằng dấu phẩy; tối đa 5 tag.',
                          prefixIcon: Icon(Icons.sell_outlined),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 16),

                      // Loại tài liệu
                      DropdownButtonFormField<DocumentType>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Loại tài liệu *',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: DocumentType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mô tả
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả tóm tắt',
                          hintText: 'Ghi chú ngắn về tài liệu (tùy chọn)...',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Vị trí vật lý
                      LocationField(
                        locationName: _locationName,
                        latitude: _latitude,
                        longitude: _longitude,
                        onLocationNameChanged: (value) {
                          setState(() => _locationName = value);
                        },
                        onLocationChanged: (selection) {
                          setState(() {
                            _latitude = selection?.latitude;
                            _longitude = selection?.longitude;
                            if (selection == null) _locationName = '';
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Khu vực đính kèm file (Supabase Storage)
                      Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tệp tài liệu (Supabase Storage)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (_selectedFileName != null) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.insert_drive_file,
                                    color: Colors.indigo,
                                  ),
                                  title: Text(
                                    _selectedFileName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'File mới được chọn (sẵn sàng tải lên)',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Bỏ chọn',
                                    onPressed: () {
                                      setState(() {
                                        _selectedFile = null;
                                        _selectedFileBytes = null;
                                        _selectedFileName = null;
                                      });
                                    },
                                  ),
                                ),
                              ] else if (_existingFileUrl.isNotEmpty) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.cloud_done,
                                    color: Colors.green,
                                  ),
                                  title: Text(
                                    _existingFileName.isNotEmpty
                                        ? _existingFileName
                                        : 'Đã có file trên Cloud Storage',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'File đang lưu trên Supabase Storage',
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  'Chưa có file nào được chọn. Bạn có thể chọn file từ máy để lưu trữ trên Cloud.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.folder_open),
                                label: Text(
                                  _selectedFileName != null ||
                                          _existingFileUrl.isNotEmpty
                                      ? 'Chọn file khác'
                                      : 'Chọn file từ thiết bị',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Nút Lưu
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _save,
                        icon: Icon(
                          widget.isEditing ? Icons.save : Icons.cloud_upload,
                        ),
                        label: Text(
                          widget.isEditing
                              ? 'Cập nhật tài liệu'
                              : 'Lưu tài liệu lên Supabase',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
