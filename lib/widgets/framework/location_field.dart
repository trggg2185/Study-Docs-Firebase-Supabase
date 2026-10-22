import 'package:flutter/material.dart';

import '../../pages/location_picker_page.dart';
import '../../struct/location_data.dart';

class LocationField extends StatefulWidget {
  final String locationName;
  final double? latitude;
  final double? longitude;
  final ValueChanged<String> onLocationNameChanged;
  final ValueChanged<LocationSelection?> onLocationChanged;

  const LocationField({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.onLocationNameChanged,
    required this.onLocationChanged,
  });

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.locationName);
  }

  @override
  void didUpdateWidget(covariant LocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationName != widget.locationName &&
        _nameController.text != widget.locationName) {
      _nameController.value = TextEditingValue(
        text: widget.locationName,
        selection: TextSelection.collapsed(offset: widget.locationName.length),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation(BuildContext context) async {
    final selection = await Navigator.of(context).push<LocationSelection>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: widget.latitude,
          initialLongitude: widget.longitude,
        ),
      ),
    );
    if (selection != null) widget.onLocationChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = widget.latitude != null && widget.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Tên vị trí (không bắt buộc)',
            hintText: 'Ví dụ: Kệ A3 - Phòng 201',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if ((value ?? '').trim().length > 100) {
              return 'Tên vị trí không được quá 100 ký tự';
            }
            return null;
          },
          onChanged: widget.onLocationNameChanged,
        ),
        OutlinedButton.icon(
          onPressed: () => _chooseLocation(context),
          icon: const Icon(Icons.map_outlined),
          label: Text(
            hasCoordinates ? 'Thay đổi vị trí trên bản đồ' : 'Chọn trên bản đồ',
          ),
        ),
        if (hasCoordinates) ...[
          const SizedBox(height: 4),
          Text(
            'Lat: ${widget.latitude!.toStringAsFixed(6)}, '
            'Lng: ${widget.longitude!.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onLocationChanged(null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa vị trí'),
            ),
          ),
        ],
      ],
    );
  }
/// Callback khi người dùng chọn/xoá vị trí.
/// name rỗng + lat/lng null nghĩa là xoá vị trí.
typedef LocationChanged =
    void Function(String name, double? latitude, double? longitude);

/// Ô nhập/chọn vị trí vật lý của tài liệu.
/// TODO(duc): thay stub bằng ô tên vị trí + nút mở LocationPickerPage.
class LocationField extends StatelessWidget {
  final String initialName;
  final double? initialLatitude;
  final double? initialLongitude;
  final LocationChanged onChanged;

  const LocationField({
    super.key,
    this.initialName = '',
    this.initialLatitude,
    this.initialLongitude,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
