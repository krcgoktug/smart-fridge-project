import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/banana_analysis.dart';
import 'camera_service.dart';
import 'firebase_service.dart';

/// Pixel-based banana browning analysis — **no AI / ML**.
///
/// Each pixel is classified with simple RGB thresholds as banana flesh
/// (yellow), a brown overripe spot, or a dark/black spot. The brown and dark
/// pixel counts are expressed as percentages of the banana region.
class BananaAnalysisService {
  static const String demoAsset = 'assets/demo/sample_banana.png';

  /// Capture an image from the ESP32-CAM (or demo asset), analyze it, and
  /// save the result to Firebase.
  static Future<BananaAnalysis> analyze({
    required String productId,
    String? captureUrl,
  }) async {
    final Uint8List bytes = await CameraService.capture(
      demoAsset: demoAsset,
      captureUrl: captureUrl,
    );
    final BananaAnalysis result = analyzeBytes(bytes, productId);
    await FirebaseService.saveBananaAnalysis(result);
    return result;
  }

  /// Analyze raw image bytes. Exposed separately so it can be unit-tested.
  static BananaAnalysis analyzeBytes(Uint8List bytes, String productId) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return BananaAnalysis.empty(productId);

    // Downscale large images for speed; the ratios are scale-independent.
    final img.Image image = decoded.width > 360
        ? img.copyResize(decoded, width: 360)
        : decoded;

    int bananaPixels = 0;
    int brownPixels = 0;
    int darkPixels = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel p = image.getPixel(x, y);
        final int r = p.r.toInt();
        final int g = p.g.toInt();
        final int b = p.b.toInt();
        final double brightness = (r + g + b) / 3.0;

        // Very dark pixel -> black/dark spot.
        final bool isDark = brightness < 60;
        // Warm, mid-to-dark pixel -> brown overripe spot.
        final bool isBrown = !isDark &&
            brightness < 150 &&
            r > 60 &&
            r >= g &&
            g >= b &&
            (r - b) > 25;
        // Bright warm pixel -> healthy yellow banana flesh.
        final bool isYellow = !isDark &&
            !isBrown &&
            r > 140 &&
            g > 120 &&
            (r - b) > 45;

        if (isDark || isBrown || isYellow) {
          bananaPixels++;
          if (isDark) {
            darkPixels++;
          } else if (isBrown) {
            brownPixels++;
          }
        }
      }
    }

    if (bananaPixels == 0) return BananaAnalysis.empty(productId);

    final double brownPct = brownPixels / bananaPixels * 100.0;
    final double darkPct = darkPixels / bananaPixels * 100.0;
    final double total = brownPct + darkPct;

    return BananaAnalysis(
      productId: productId,
      brownSpotPercentage: brownPct,
      darkSpotPercentage: darkPct,
      totalBrowningPercentage: total,
      visualStatus: BananaAnalysis.statusForPercentage(total),
    );
  }
}
