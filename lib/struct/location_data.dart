/// Vị trí được chọn trên bản đồ hoặc nhập trong form tài liệu.
class LocationSelection {
  final double latitude;
  final double longitude;

  const LocationSelection({required this.latitude, required this.longitude});

  static String? validate({
    required String locationName,
    required double? latitude,
    required double? longitude,
  }) {
    if (locationName.trim().length > 100) {
      return 'Tên vị trí không được quá 100 ký tự';
    }
    if ((latitude == null) != (longitude == null)) {
      return 'Latitude và longitude phải được nhập cùng nhau';
    }
    if (latitude != null &&
        (!latitude.isFinite || latitude < -90 || latitude > 90)) {
      return 'Latitude phải nằm trong khoảng -90 đến 90';
    }
    if (longitude != null &&
        (!longitude.isFinite || longitude < -180 || longitude > 180)) {
      return 'Longitude phải nằm trong khoảng -180 đến 180';
    }
    return null;
  }
}
