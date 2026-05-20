import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// Mobile / desktop MJPEG widget. The browser-native HTML `<img>` element is
/// used on web instead (see camera_stream_web.dart) because the multipart
/// MJPEG protocol is decoded natively there.
class CameraStream extends StatelessWidget {
  const CameraStream({
    super.key,
    required this.streamUrl,
    required this.captureUrl,
  });

  final String streamUrl;
  final String captureUrl;

  @override
  Widget build(BuildContext context) {
    return Mjpeg(
      key: ValueKey<String>(streamUrl),
      stream: streamUrl,
      isLive: true,
      fit: BoxFit.contain,
      error: (BuildContext context, dynamic e, dynamic s) => const Center(
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
