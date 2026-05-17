import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../widgets/firebase_notice.dart';

/// Screen 5 - Camera View.
///
/// The ESP32-CAM serves an MJPEG stream and a single-frame /capture endpoint.
/// To stay dependency-light this screen polls the /capture image on a timer
/// (a lightweight "live view"); the raw stream URL is also shown so it can be
/// opened in a browser for a true MJPEG feed.
class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  Timer? _timer;
  int _tick = 0;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_autoRefresh && mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera View'),
        actions: <Widget>[
          IconButton(
            tooltip: _autoRefresh ? 'Pause' : 'Resume',
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: () =>
                setState(() => _autoRefresh = !_autoRefresh),
          ),
          IconButton(
            tooltip: 'Refresh now',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _tick++),
          ),
        ],
      ),
      body: FirebaseService.ready
          ? _body()
          : const FirebaseNotice(),
    );
  }

  Widget _body() {
    return StreamBuilder<CameraInfo>(
      stream: FirebaseService.cameraStream(),
      builder: (BuildContext context, AsyncSnapshot<CameraInfo> snap) {
        final CameraInfo cam = snap.data ?? CameraInfo();
        if (!cam.hasUrls) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No camera URL published yet.\n\n'
                'Power on the ESP32-CAM. It writes its streamUrl and '
                'captureUrl to /devices/fridge_01/camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
            ),
          );
        }
        // Cache-busting URL so each tick fetches a fresh frame.
        final String imageUrl = '${cam.captureUrl}?t=$_tick';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: Colors.black,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.videocam_off,
                              color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text(
                            'Cannot reach the camera.\n'
                            'Phone and ESP32-CAM must share the same Wi-Fi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Camera endpoints',
                        style:
                            TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _UrlRow(label: 'Stream', url: cam.streamUrl ?? '-'),
                    const SizedBox(height: 6),
                    _UrlRow(
                        label: 'Capture', url: cam.captureUrl ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              color: Color(0xFFEFF4EF),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Tip: banana browning analysis uses this capture image. '
                  'Run the optional Python backend, or analyze on-device, '
                  'to update browningRatio and visualStatus.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: SelectableText(
            url,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }
}
