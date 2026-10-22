import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentLocationCard extends StatelessWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;

  const DocumentLocationCard({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  Future<void> _openMap(BuildContext context) async {
    final uri = Uri.https('www.openstreetmap.org', '/', {
      'mlat': '$latitude',
      'mlon': '$longitude',
      'zoom': '17',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không thể mở bản đồ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = locationName?.trim() ?? '';
    final hasCoordinates = latitude != null && longitude != null;

    if (name.isEmpty && !hasCoordinates) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vị trí tài liệu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (name.isNotEmpty) ...[const SizedBox(height: 8), Text(name)],
            if (hasCoordinates) ...[
              const SizedBox(height: 4),
              Text(
                'Lat: ${latitude!.toStringAsFixed(6)}, '
                'Lng: ${longitude!.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openMap(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở bản đồ'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
