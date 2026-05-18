import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// Live MJPEG view for the mobile / desktop build.
///
/// Uses the `flutter_mjpeg` package, which decodes the multipart stream and
/// renders it frame by frame. The web build uses a different implementation
/// (see `camera_stream_web.dart`) selected by a conditional import.
class CameraStream extends StatelessWidget {
  const CameraStream({super.key, required this.streamUrl});

  final String streamUrl;

  @override
  Widget build(BuildContext context) {
    return Mjpeg(
      stream: streamUrl,
      isLive: true,
      fit: BoxFit.contain,
      error: (BuildContext context, dynamic error, dynamic stack) =>
          const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cannot reach the camera stream.\n'
            'This device must be on the same Wi-Fi as the ESP32-CAM.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      ),
    );
  }
}
