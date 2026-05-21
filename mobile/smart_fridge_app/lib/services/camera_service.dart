import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Talks to the ESP32-CAM over the local network: tests the connection,
/// grabs a frame, and decodes a QR code from it.
///
/// The app never fakes a working camera — every result here is a real HTTP
/// request to the configured ESP32-CAM address.
class CameraService {
  /// Returns true if the camera answers `/capture` with a real image.
  static Future<bool> testConnection(String captureUrl) async {
    if (captureUrl.isEmpty) return false;
    try {
      final http.Response resp = await http
          .get(Uri.parse(captureUrl))
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 200 && resp.bodyBytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Fetches one JPEG frame from `/capture`, or null if the camera is
  /// unreachable.
  static Future<Uint8List?> captureImage(String captureUrl) async {
    if (captureUrl.isEmpty) return null;
    try {
      final http.Response resp = await http
          .get(Uri.parse(captureUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    } catch (_) {
      // unreachable -> null
    }
    return null;
  }

  /// Decodes a QR code from JPEG bytes. Pure Dart (zxing2). Returns the QR
  /// text, or null when no QR code is found. Tries two binarizers for
  /// robustness against difficult lighting / angles.
  ///
  /// Only finds ONE code per frame. For a box with several QR stickers use
  /// [decodeQrCodes], which scans sub-regions to catch each one.
  static String? decodeQr(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return _decodeRegion(decoded);
  }

  /// Decodes EVERY distinct QR code visible in the frame.
  ///
  /// zxing2 only locks onto a single code per decode call, so we scan the
  /// full frame plus a grid of overlapping tiles. A QR sticker that sits on
  /// its own inside one tile decodes reliably even when other stickers are
  /// elsewhere in the box. Returns the set of unique QR strings found
  /// (empty when none).
  static Set<String> decodeQrCodes(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return <String>{};

    final Set<String> found = <String>{};

    // 1) Full frame, both binarizers (best shot at the clearest code).
    final String? full = _decodeRegion(decoded);
    if (full != null && full.isNotEmpty) found.add(full);

    // 2) 3x3 overlapping tiles (each ~50% of the frame, stepping 25%) so a
    //    code anywhere in the box ends up alone inside at least one tile.
    final int w = decoded.width;
    final int h = decoded.height;
    final int tw = (w * 0.5).round();
    final int th = (h * 0.5).round();
    final List<int> xs = <int>[0, ((w - tw) * 0.5).round(), w - tw];
    final List<int> ys = <int>[0, ((h - th) * 0.5).round(), h - th];

    for (final int y in ys.toSet()) {
      for (final int x in xs.toSet()) {
        final img.Image tile =
            img.copyCrop(decoded, x: x, y: y, width: tw, height: th);
        final String? t = _decodeRegion(tile, hybridOnly: true);
        if (t != null && t.isNotEmpty) found.add(t);
      }
    }
    return found;
  }

  /// Tries to decode a single QR from one image region. Hybrid binarizer
  /// first (varying light), then global histogram (uniform light) unless
  /// [hybridOnly] is set to keep tile scanning fast.
  static String? _decodeRegion(img.Image region, {bool hybridOnly = false}) {
    final source = RGBLuminanceSource(
      region.width,
      region.height,
      region
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List(),
    );
    final reader = QRCodeReader();
    try {
      return reader.decode(BinaryBitmap(HybridBinarizer(source))).text;
    } catch (_) {}
    if (hybridOnly) return null;
    try {
      return reader.decode(BinaryBitmap(GlobalHistogramBinarizer(source))).text;
    } catch (_) {
      return null;
    }
  }
}
