import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../services/settings_service.dart';

/// Screen 3 - Camera. Shows the live ESP32-CAM MJPEG stream.
class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  @override
  Widget build(BuildContext context) {
    final String streamUrl = SettingsService.streamUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (kIsWeb) const _WebLimitationNote(),
          if (kIsWeb) const SizedBox(height: 14),
          _StreamView(streamUrl: streamUrl),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('ESP32-CAM stream',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    streamUrl.isEmpty
                        ? 'No camera address set. Open Settings and enter '
                            'the ESP32-CAM IP.'
                        : streamUrl,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamView extends StatelessWidget {
  const _StreamView({required this.streamUrl});
  final String streamUrl;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (streamUrl.isEmpty) {
      child = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Set the ESP32-CAM IP in Settings to view the live stream.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    } else {
      child = Mjpeg(
        stream: streamUrl,
        isLive: true,
        fit: BoxFit.contain,
        error: (BuildContext context, dynamic error, dynamic stack) =>
            const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Cannot reach the camera stream.\n'
              'The device must be on the same Wi-Fi as the ESP32-CAM.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(color: Colors.black, child: child),
      ),
    );
  }
}

class _WebLimitationNote extends StatelessWidget {
  const _WebLimitationNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3CD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Color(0xFF8A6D00)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hardware Mode requires the Android app or a local Flutter '
                'run. The GitHub Pages site is HTTPS and browsers block the '
                "ESP32-CAM's HTTP stream (mixed content).",
                style: TextStyle(fontSize: 12.5, color: Color(0xFF8A6D00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
