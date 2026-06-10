import 'dart:async';

import 'package:flutter/material.dart';

/// Web "live stream": fetches /capture frames ONE AT A TIME. It loads a
/// frame, shows it, waits a short gap, then requests the next. This
/// self-pacing matters because the ESP32-CAM serves /capture from a single
/// task: blindly polling every 300 ms piles up overlapping requests and
/// jams the camera. Waiting for each frame before asking for the next keeps
/// at most one request in flight, so a slow camera never gets flooded.
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
  // Gap between a frame finishing and requesting the next one.
  static const Duration _gap = Duration(milliseconds: 200);
  // Wait before retrying after a failed frame.
  static const Duration _retryGap = Duration(seconds: 1);

  ImageProvider? _current; // last successfully decoded frame
  bool _disposed = false;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  @override
  void didUpdateWidget(covariant CameraStream old) {
    super.didUpdateWidget(old);
    // Address changed -> restart the loop with the new URL.
    if (old.captureUrl != widget.captureUrl) {
      _current = null;
      _hadError = false;
      _loadNext();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _loadNext() {
    if (_disposed || widget.captureUrl.isEmpty) return;
    final String url =
        '${widget.captureUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
    final ImageProvider provider = NetworkImage(url);
    final ImageStream stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        if (_disposed) return;
        if (mounted) {
          setState(() {
            _current = provider;
            _hadError = false;
          });
        }
        // Only ask for the next frame once this one decoded.
        Future<void>.delayed(_gap, _loadNext);
      },
      onError: (Object e, StackTrace? st) {
        stream.removeListener(listener);
        if (_disposed) return;
        if (mounted && !_hadError) setState(() => _hadError = true);
        Future<void>.delayed(_retryGap, _loadNext);
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.captureUrl.isEmpty) {
      return const Center(
        child: Text('No camera address',
            style: TextStyle(color: Colors.white60)),
      );
    }
    if (_current != null) {
      // gaplessPlayback keeps the previous frame on screen while the next
      // one decodes, so there is no black flicker between frames.
      return Image(image: _current!, fit: BoxFit.contain, gaplessPlayback: true);
    }
    if (_hadError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Camera unavailable. Make sure the ESP32-CAM and this device '
            'are connected to the same Wi-Fi/network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white24),
    );
  }
}
