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
  /// text, or null when no QR code is found.
  static String? decodeQr(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final source = RGBLuminanceSource(
      decoded.width,
      decoded.height,
      decoded
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List(),
    );
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    try {
      return QRCodeReader().decode(bitmap).text;
    } catch (_) {
      return null;
    }
  }
}
