import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../models/camera_info.dart';
import '../models/detection_event.dart';
import '../models/product.dart';
import 'demo_data.dart';
import 'firebase_service.dart';

/// Outcome of an automatic registration attempt.
enum AutoRegStatus { ignored, success, failure }

class AutoRegistrationResult {
  AutoRegistrationResult(this.status, {this.product, this.message = ''});

  final AutoRegStatus status;
  final Product? product;
  final String message;

  factory AutoRegistrationResult.ignored() =>
      AutoRegistrationResult(AutoRegStatus.ignored);
  factory AutoRegistrationResult.success(Product p) =>
      AutoRegistrationResult(AutoRegStatus.success, product: p);
  factory AutoRegistrationResult.failure(String m) =>
      AutoRegistrationResult(AutoRegStatus.failure, message: m);
}

/// Drives the **automatic** product registration flow.
///
/// Triggered by a weight-change [DetectionEvent] from the ESP32 DevKit:
///   1. fetch the still image from the ESP32-CAM `/capture` URL,
///   2. decode the QR code from that image (pure-Dart, on-device),
///   3. parse the product JSON and save it to Firebase,
///   4. reset the detection flag.
///
/// In demo mode the capture+decode steps are simulated with sample data so
/// the whole flow can be shown without any hardware.
class AutoRegistrationService {
  /// Handle one detection event. Safe to call for any event — non-addition
  /// events are ignored.
  static Future<AutoRegistrationResult> register({
    required DetectionEvent event,
    required CameraInfo camera,
  }) async {
    if (!event.newProductDetected || !event.isAddition) {
      return AutoRegistrationResult.ignored();
    }

    Product? product;
    String? error;

    try {
      if (FirebaseService.demoMode) {
        // Simulated: the demo "camera" already knows which product it sees.
        product = DemoRepository.instance.takePendingSimulatedProduct();
        error = product == null ? 'No simulated product available.' : null;
      } else {
        // Real hardware: capture an image and decode its QR code.
        if (!camera.hasUrls) {
          error = 'Camera URL not published yet.';
        } else {
          final Uint8List bytes = await _fetchCapture(camera.captureUrl!);
          final String? qrText = decodeQrFromBytes(bytes);
          if (qrText == null) {
            error = 'No QR code found in the captured image.';
          } else {
            product = _parseProduct(qrText);
            if (product == null) {
              error = 'QR code did not contain valid product data.';
            }
          }
        }
      }
    } catch (e) {
      error = e.toString();
    }

    if (product != null && product.productId.isNotEmpty) {
      await FirebaseService.saveProduct(product);
      await FirebaseService.addAlert(
        'Product auto-registered: ${product.name}',
        'info',
        productId: product.productId,
      );
      await FirebaseService.resetDetection();
      return AutoRegistrationResult.success(product);
    }

    // Clear the flag even on failure so the system is not stuck.
    await FirebaseService.resetDetection();
    return AutoRegistrationResult.failure(error ?? 'Registration failed.');
  }

  /// Download a single JPEG frame from the ESP32-CAM `/capture` endpoint.
  static Future<Uint8List> _fetchCapture(String url) async {
    final http.Response resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw 'Camera returned HTTP ${resp.statusCode}';
    }
    return resp.bodyBytes;
  }

  /// Decode a QR code from raw image bytes. Pure Dart (zxing2) so it works
  /// on mobile and web alike. Returns null when no QR code is found.
  static String? decodeQrFromBytes(Uint8List bytes) {
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
      final result = QRCodeReader().decode(bitmap);
      return result.text;
    } catch (_) {
      return null; // NotFoundException / ChecksumException / FormatException
    }
  }

  /// Parse a QR JSON payload into a [Product]; null if it is not valid.
  static Product? _parseProduct(String qrText) {
    try {
      final dynamic decoded = jsonDecode(qrText);
      if (decoded is! Map) return null;
      final Map<String, dynamic> map =
          decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
      if ((map['productId'] ?? '').toString().isEmpty) return null;
      return Product.fromQrJson(map);
    } catch (_) {
      return null;
    }
  }
}
