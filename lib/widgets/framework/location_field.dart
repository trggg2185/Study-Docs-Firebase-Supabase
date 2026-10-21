import 'package:flutter/material.dart';

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
