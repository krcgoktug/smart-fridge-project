import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import 'firebase_service.dart';

/// Raised when a still image cannot be obtained from the ESP32-CAM.
class CameraCaptureException implements Exception {
  CameraCaptureException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the ESP32-CAM: fetches still images and decodes QR codes from
/// them. The ESP32-CAM only serves the image — all decoding happens here.
class CameraService {
  /// Capture a still image.
  ///
  /// - Demo mode: returns the bundled [demoAsset].
  /// - Hardware mode: HTTP GET of [captureUrl] (the ESP32-CAM `/capture`).
  static Future<Uint8List> capture({
    required String demoAsset,
    String? captureUrl,
  }) async {
    if (FirebaseService.demoMode) {
      final data = await rootBundle.load(demoAsset);
      return data.buffer.asUint8List();
    }
    if (captureUrl == null || captureUrl.trim().isEmpty) {
      throw CameraCaptureException(
        'No camera address. Set the ESP32-CAM IP in Settings.',
      );
    }
    try {
      final http.Response resp = await http
          .get(Uri.parse(captureUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw CameraCaptureException(
            'Camera returned HTTP ${resp.statusCode}.');
      }
      if (resp.bodyBytes.isEmpty) {
        throw CameraCaptureException('Camera returned an empty image.');
      }
      return resp.bodyBytes;
    } on CameraCaptureException {
      rethrow;
    } catch (_) {
      throw CameraCaptureException(
        'Could not reach the camera at $captureUrl. '
        'Check the IP in Settings and the Wi-Fi network.',
      );
    }
  }

  /// Decode a QR code from raw image bytes. Pure Dart (zxing2) so it works
  /// on mobile and web. Returns the QR text, or null when none is found.
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
      return null; // NotFoundException / ChecksumException / FormatException
    }
  }
}
