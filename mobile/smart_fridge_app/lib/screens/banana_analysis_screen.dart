import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/banana_analysis.dart';
import '../models/camera_info.dart';
import '../models/product.dart';
import '../services/banana_analysis_service.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';

/// Banana Analysis screen — pixel-based browning analysis of a camera image.
class BananaAnalysisScreen extends StatefulWidget {
  const BananaAnalysisScreen({super.key});

  @override
  State<BananaAnalysisScreen> createState() => _BananaAnalysisScreenState();
}

class _BananaAnalysisScreenState extends State<BananaAnalysisScreen> {
  String? _productId;
  bool _analyzing = false;

  Future<void> _analyze(String? firebaseCaptureUrl) async {
    final String productId = _productId ?? 'banana_001';
    setState(() => _analyzing = true);
    try {
      final BananaAnalysis result = await BananaAnalysisService.analyze(
        productId: productId,
        captureUrl: SettingsService.resolveCaptureUrl(firebaseCaptureUrl),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: StatusColors.forVisualStatus(result.visualStatus),
          content: Text(
            'Analysis complete: ${result.visualStatus} '
            '(${result.totalBrowningPercentage.toStringAsFixed(1)}%)',
          ),
        ));
    } on CameraCaptureException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), backgroundColor: StatusColors.spoilage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banana Analysis')),
      body: StreamBuilder<List<Product>>(
        stream: FirebaseService.productsStream(),
        builder: (BuildContext context,
            AsyncSnapshot<List<Product>> productSnap) {
          // Candidate products: fruit items (default option if none exist).
          final List<Product> fruits = (productSnap.data ?? <Product>[])
              .where((Product p) => p.category == 'Fruit')
              .toList();
          final List<MapEntry<String, String>> options = fruits.isEmpty
              ? <MapEntry<String, String>>[
                  const MapEntry<String, String>('banana_001', 'Banana')
                ]
              : fruits
                  .map((Product p) =>
                      MapEntry<String, String>(p.productId, p.name))
                  .toList();
          _productId ??= options.first.key;
          if (!options.any((e) => e.key == _productId)) {
            _productId = options.first.key;
          }

          return StreamBuilder<CameraInfo>(
            stream: FirebaseService.cameraStream(),
            builder: (BuildContext context,
                AsyncSnapshot<CameraInfo> camSnap) {
              final CameraInfo cam = camSnap.data ?? CameraInfo();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const _BananaImage(),
                  const SizedBox(height: 16),
                  _ProductSelector(
                    options: options,
                    value: _productId!,
                    onChanged: (String v) =>
                        setState(() => _productId = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _analyzing
                        ? null
                        : () => _analyze(cam.captureUrl),
                    icon: _analyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.biotech),
                    label: Text(_analyzing
                        ? 'Analyzing...'
                        : 'Analyze Banana'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 18),
                  _ResultCard(productId: _productId!),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Latest banana image (demo asset or live camera capture).
class _BananaImage extends StatelessWidget {
  const _BananaImage();

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (FirebaseService.demoMode) {
      child = Image.asset('assets/demo/sample_banana.png',
          fit: BoxFit.contain);
    } else {
      final String url = SettingsService.configuredCaptureUrl;
      child = url.isEmpty
          ? const Center(
              child: Text('Set the camera IP in Settings',
                  style: TextStyle(color: Colors.white60)))
          : Image.network(url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                    child: Text('Camera unavailable',
                        style: TextStyle(color: Colors.white60)),
                  ));
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

class _ProductSelector extends StatelessWidget {
  const _ProductSelector({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<MapEntry<String, String>> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      decoration: const InputDecoration(
        labelText: 'Banana product',
        border: OutlineInputBorder(),
      ),
      items: options
          .map((MapEntry<String, String> e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text('${e.value}  (${e.key})'),
              ))
          .toList(),
      onChanged: (String? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Shows the stored browning result for [productId].
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.productId});
  final String productId;

  Widget _bar(String label, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('${pct.toStringAsFixed(1)} %',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.black12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BananaAnalysis>>(
      stream: FirebaseService.bananaAnalysisStream(),
      builder: (BuildContext context,
          AsyncSnapshot<List<BananaAnalysis>> snap) {
        final List<BananaAnalysis> all = snap.data ?? <BananaAnalysis>[];
        BananaAnalysis? result;
        for (final BananaAnalysis a in all) {
          if (a.productId == productId) result = a;
        }

        if (result == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No analysis yet. Press "Analyze Banana" to measure the '
                'browning of the latest camera image.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        final Color statusColor =
            StatusColors.forVisualStatus(result.visualStatus);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text('Browning result',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(result.visualStatus,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _bar('Brown spots', result.brownSpotPercentage,
                        const Color(0xFF8D6E3A)),
                    _bar('Dark spots', result.darkSpotPercentage,
                        const Color(0xFF3E2C1C)),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text('Total browning',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${result.totalBrowningPercentage.toStringAsFixed(1)} %',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: statusColor),
                        ),
                      ],
                    ),
                    if (result.updatedAt > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Updated ${DateFormat('dd MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(result.updatedAt.toInt() * 1000))}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (result.needsWarning)
              Card(
                color: const Color(0xFFFDECEA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded,
                          color: StatusColors.spoilage),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(result.warningMessage,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
