import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Live MJPEG view for the web build.
///
/// A browser renders a `multipart/x-mixed-replace` MJPEG stream natively in
/// an `<img>` element, and an `<img>` is not subject to CORS for display.
/// That is far more reliable on the web than decoding the stream in Dart.
///
/// Note: this still cannot work when the app itself is served over HTTPS —
/// the browser blocks the camera's plain-HTTP stream as mixed content. It
/// works on a local HTTP run (e.g. `flutter run -d chrome`).
class CameraStream extends StatelessWidget {
  const CameraStream({super.key, required this.streamUrl});

  final String streamUrl;

  /// View types may only be registered once per app session.
  static final Set<String> _registered = <String>{};

  @override
  Widget build(BuildContext context) {
    final String viewType = 'esp32cam:$streamUrl';
    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final web.HTMLImageElement img = web.HTMLImageElement();
          img.src = streamUrl;
          img.style.width = '100%';
          img.style.height = '100%';
          img.style.objectFit = 'contain';
          img.style.background = '#000000';
          return img;
        },
      );
    }
    return HtmlElementView(viewType: viewType);
  }
}
