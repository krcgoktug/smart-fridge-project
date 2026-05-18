import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/camera_info.dart';
import '../models/product.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';
import 'banana_analysis_screen.dart';

/// Screen 5 - Camera. Hub for the two camera-driven features:
///   - "Scan QR from Camera"  -> capture an image and register a product,
///   - "Analyze Banana"       -> open the banana browning analysis screen.
///
/// The ESP32-CAM only provides the image; QR decoding happens here.
class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  bool _scanning = false;

  Future<void> _scanQr(String? firebaseCaptureUrl) async {
    setState(() => _scanning = true);
    final String captureUrl =
        SettingsService.resolveCaptureUrl(firebaseCaptureUrl);
    try {
      final Uint8List bytes = await CameraService.capture(
        demoAsset: 'assets/demo/sample_qr.png',
        captureUrl: captureUrl,
      );
      final String? qrText = CameraService.decodeQr(bytes);
      if (qrText == null) {
        _snack('No QR code found in the captured image.',
            StatusColors.spoilage);
        return;
      }
      final Product? product = _parseProduct(qrText);
      if (product == null) {
        _snack('QR code does not contain valid product data.',
            StatusColors.spoilage);
        return;
      }
      if (!mounted) return;
      final bool? confirmed = await _showConfirm(product);
      if (confirmed != true) return;
      await FirebaseService.saveProduct(product);
      await FirebaseService.addAlert(
        '${product.name} registered from a QR code.',
        'info',
        productId: product.productId,
      );
      _snack('${product.name} saved.', StatusColors.fresh);
    } on CameraCaptureException catch (e) {
      _snack(e.message, StatusColors.spoilage);
    } catch (e) {
      _snack('Scan failed: $e', StatusColors.spoilage);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Product? _parseProduct(String qrText) {
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

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<bool?> _showConfirm(Product p) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: <Widget>[
              SizedBox(
                  width: 110,
                  child: Text(k,
                      style: const TextStyle(color: Colors.black54))),
              Expanded(
                  child: Text(v,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
        );
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.qr_code_2, color: StatusColors.fresh),
                const SizedBox(width: 8),
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 22),
            row('Product ID', p.productId),
            row('Category', p.category),
            row('Brand', p.brand),
            row('Expiry date', p.expiryDate),
            row('Added date', p.addedDate),
            row('Expected weight', '${p.expectedWeight} g'),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.save),
                    label: const Text('Save product'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: StreamBuilder<CameraInfo>(
        stream: FirebaseService.cameraStream(),
        builder: (BuildContext context, AsyncSnapshot<CameraInfo> snap) {
          final CameraInfo cam = snap.data ?? CameraInfo();
          final String captureUrl =
              SettingsService.resolveCaptureUrl(cam.captureUrl);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ModeBanner(captureUrl: captureUrl),
              const SizedBox(height: 14),
              _CapturePreview(captureUrl: captureUrl),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _scanning ? null : () => _scanQr(cam.captureUrl),
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_scanner),
                label: Text(_scanning
                    ? 'Scanning...'
                    : 'Scan QR from Camera'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BananaAnalysisScreen(),
                  ),
                ),
                icon: const Icon(Icons.local_florist),
                label: const Text('Analyze Banana'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 16),
              const Card(
                color: Color(0xFFEFF4EF),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'The ESP32-CAM only provides the image. The QR code is '
                    'decoded on the phone. Set the camera IP in Settings; '
                    'in Demo mode bundled sample images are used.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows whether the app is in Demo or Hardware mode.
class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.captureUrl});
  final String captureUrl;

  @override
  Widget build(BuildContext context) {
    final bool demo = FirebaseService.demoMode;
    final Color color = demo ? StatusColors.consumeSoon : StatusColors.fresh;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: <Widget>[
          Icon(demo ? Icons.science : Icons.memory, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              demo
                  ? 'Demo mode — sample QR / banana images are used.'
                  : (captureUrl.isEmpty
                      ? 'Hardware mode — set the ESP32-CAM IP in Settings.'
                      : 'Hardware mode — camera: $captureUrl'),
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live preview of the camera image (polled in hardware mode).
class _CapturePreview extends StatefulWidget {
  const _CapturePreview({required this.captureUrl});
  final String captureUrl;

  @override
  State<_CapturePreview> createState() => _CapturePreviewState();
}

class _CapturePreviewState extends State<_CapturePreview> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (!FirebaseService.demoMode) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _tick++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (FirebaseService.demoMode) {
      child = Image.asset('assets/demo/sample_qr.png', fit: BoxFit.contain);
    } else if (widget.captureUrl.isEmpty) {
      child = const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No camera address.\nSet the ESP32-CAM IP in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    } else {
      child = Image.network(
        '${widget.captureUrl}?t=$_tick',
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Cannot reach the camera.\n'
              'The phone must share the ESP32-CAM Wi-Fi network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(color: Colors.black, child: child),
      ),
    );
  }
}
