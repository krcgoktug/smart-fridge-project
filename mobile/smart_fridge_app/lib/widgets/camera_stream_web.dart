import 'dart:async';

import 'package:flutter/material.dart';

/// Web "live stream": polls /capture every ~300 ms with Image.network and
/// displays the latest frame. This avoids the HtmlElementView/MJPEG render
/// glitches and works reliably in every browser, as long as the device is
/// on the SAME Wi-Fi as the ESP32-CAM.
class CameraStream extends StatefulWidget {
  const CameraStream({
    super.key,
    required this.streamUrl,
    required this.captureUrl,
  });

  final String streamUrl;
  final String captureUrl;

  @override
  State<CameraStream> createState() => _CameraStreamState();
}

class _CameraStreamState extends State<CameraStream> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.captureUrl.isEmpty) {
      return const Center(
        child: Text('No camera address',
            style: TextStyle(color: Colors.white60)),
      );
    }
    final String url = '${widget.captureUrl}?t=$_tick';
    return Image.network(
      url,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Camera unavailable. Make sure the ESP32-CAM and this device '
            'are connected to the same Wi-Fi/network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
