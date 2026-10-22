import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../struct/location_data.dart';

/// Bộ chọn tọa độ trên nền tile OpenStreetMap, không cần API key.
class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const double _tileSize = 256;
  static const double _mapSize = _tileSize * 3;
  static const double _initialLatitude = 21.0285;
  static const double _initialLongitude = 105.8542;

  late final TransformationController _transformController;
  late double _centerLatitude;
  late double _centerLongitude;
  late int _zoom;
  LocationSelection? _selection;

  @override
  void initState() {
    super.initState();
    _centerLatitude = widget.initialLatitude ?? _initialLatitude;
    _centerLongitude = widget.initialLongitude ?? _initialLongitude;
    _selection =
        widget.initialLatitude != null && widget.initialLongitude != null
        ? LocationSelection(
            latitude: widget.initialLatitude!,
            longitude: widget.initialLongitude!,
          )
        : null;
    _zoom = 13;
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  ({double x, double y}) _toWorldPixels(double latitude, double longitude) {
    final scale = math.pow(2, _zoom).toDouble() * _tileSize;
    final boundedLatitude = latitude
        .clamp(-85.05112878, 85.05112878)
        .toDouble();
    final sinLatitude = math.sin(boundedLatitude * math.pi / 180);
    final x = (longitude + 180) / 360 * scale;
    final y =
        (0.5 -
            math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
        scale;
    return (x: x, y: y);
  }

  LocationSelection _fromWorldPixels(double x, double y) {
    final scale = math.pow(2, _zoom).toDouble() * _tileSize;
    final boundedY = y.clamp(0, scale).toDouble();
    final longitude = x / scale * 360 - 180;
    final mercatorY = math.pi * (1 - 2 * boundedY / scale);
    final latitude =
        (2 * math.atan(math.exp(mercatorY)) - math.pi / 2) * 180 / math.pi;
    return LocationSelection(
      latitude: latitude.clamp(-90, 90).toDouble(),
      longitude: ((longitude + 180) % 360) - 180,
    );
  }

  void _placeMarker(TapUpDetails details) {
    final scenePosition = _transformController.toScene(details.localPosition);
    final centerTile = _toWorldPixels(_centerLatitude, _centerLongitude);
    final originX = (centerTile.x / _tileSize).floor() - 1;
    final originY = (centerTile.y / _tileSize).floor() - 1;
    final worldX = originX * _tileSize + scenePosition.dx;
    final worldY = originY * _tileSize + scenePosition.dy;

    setState(() => _selection = _fromWorldPixels(worldX, worldY));
  }

  void _changeZoom(int delta) {
    final nextZoom = (_zoom + delta).clamp(2, 19).toInt();
    if (nextZoom == _zoom) return;

    setState(() {
      _zoom = nextZoom;
      if (_selection != null) {
        _centerLatitude = _selection!.latitude;
        _centerLongitude = _selection!.longitude;
      }
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final centerTile = _toWorldPixels(_centerLatitude, _centerLongitude);
    final originX = (centerTile.x / _tileSize).floor() - 1;
    final originY = (centerTile.y / _tileSize).floor() - 1;
    final tileCount = 1 << _zoom;
    final selectionPixel = _selection == null
        ? null
        : _toWorldPixels(_selection!.latitude, _selection!.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí trên bản đồ'),
        actions: [
          TextButton(
            onPressed: _selection == null
                ? null
                : () => Navigator.of(context).pop(_selection),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize = math
                    .min(constraints.maxWidth, constraints.maxHeight)
                    .toDouble();
                final originPixelX = originX * _tileSize;
                final originPixelY = originY * _tileSize;

                return Center(
                  child: SizedBox(
                    width: viewportSize,
                    height: viewportSize,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _placeMarker,
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          constrained: false,
                          alignment: Alignment.center,
                          boundaryMargin: const EdgeInsets.all(_tileSize),
                          minScale: 0.5,
                          maxScale: 4,
                          child: SizedBox(
                            width: _mapSize,
                            height: _mapSize,
                            child: Stack(
                              children: [
                                for (var row = 0; row < 3; row++)
                                  for (var column = 0; column < 3; column++)
                                    Positioned(
                                      left: column * _tileSize,
                                      top: row * _tileSize,
                                      width: _tileSize,
                                      height: _tileSize,
                                      child: _buildTile(
                                        (originX + column) % tileCount,
                                        originY + row,
                                        tileCount,
                                      ),
                                    ),
                                if (selectionPixel != null)
                                  Positioned(
                                    left: selectionPixel.x - originPixelX - 18,
                                    top: selectionPixel.y - originPixelY - 36,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 36,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Thu nhỏ bản đồ',
                      onPressed: () => _changeZoom(-1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('Zoom $_zoom'),
                    IconButton(
                      tooltip: 'Phóng to bản đồ',
                      onPressed: () => _changeZoom(1),
                      icon: const Icon(Icons.add),
                    ),
                    const Spacer(),
                    if (_selection != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _selection = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa điểm'),
                      ),
                  ],
                ),
                Text(
                  _selection == null
                      ? 'Chạm bản đồ để đặt điểm; kéo để di chuyển bản đồ.'
                      : 'Lat: ${_selection!.latitude.toStringAsFixed(6)}  '
                            'Lng: ${_selection!.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  '© OpenStreetMap contributors',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(int x, int y, int tileCount) {
    if (y < 0 || y >= tileCount) {
      return const ColoredBox(color: Color(0xFFE5E3DF));
    }

    return Image.network(
      'https://tile.openstreetmap.org/$_zoom/$x/$y.png',
      fit: BoxFit.cover,
      headers: const {'User-Agent': 'StudyDocs/1.0'},
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Color(0xFFE5E3DF),
        child: Center(child: Icon(Icons.map_outlined)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFFE5E3DF),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
