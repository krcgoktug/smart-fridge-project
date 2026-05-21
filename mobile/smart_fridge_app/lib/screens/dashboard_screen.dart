import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/camera_config.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/alert_service.dart';
import '../services/banana_state.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';
import '../widgets/camera_stream_web.dart'
    if (dart.library.io) '../widgets/camera_stream_io.dart';
import '../widgets/product_card.dart';
import '../widgets/sensor_card.dart';

/// Screen 1 - Dashboard. Sensors, ESP32 status, camera preview, products,
/// alerts.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the 60 s ESP32 offline timeout periodically.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zero Waste Smart Fridge')),
      body: StreamBuilder<SensorData>(
        stream: FirebaseService.sensorStream(),
        builder: (BuildContext context, AsyncSnapshot<SensorData> sSnap) {
          final SensorData sensors = sSnap.data ?? SensorData();
          return StreamBuilder<List<Product>>(
            stream: FirebaseService.productsStream(),
            builder: (BuildContext context,
                AsyncSnapshot<List<Product>> pSnap) {
              final List<Product> products = pSnap.data ?? <Product>[];
              return StreamBuilder<CameraConfig>(
                stream: FirebaseService.cameraStream(),
                builder: (BuildContext context,
                    AsyncSnapshot<CameraConfig> cSnap) {
                  final CameraConfig streamed =
                      cSnap.data ?? CameraConfig();
                  // Firebase is off so the shared camera config is empty;
                  // fall back to the locally-saved ESP32-CAM IP so the
                  // dashboard preview shows the live stream too.
                  final CameraConfig camera = streamed.isConfigured
                      ? streamed
                      : CameraConfig(localIp: SettingsService.cameraIp);
                  return StreamBuilder<BananaAnalysis>(
                    stream: BananaState.stream(),
                    builder: (BuildContext context,
                        AsyncSnapshot<BananaAnalysis> bSnap) {
                      final BananaAnalysis banana =
                          bSnap.data ?? BananaAnalysis.empty();
                      final List<Alert> alerts = AlertService.derive(
                        sensors: sensors,
                        products: products,
                        banana: banana,
                      );
                      return LayoutBuilder(
                        builder: (BuildContext context,
                            BoxConstraints c) {
                          if (c.maxWidth >= 720) {
                            return _desktopBody(
                                c, sensors, camera, products, alerts);
                          }
                          return _phoneBody(
                              sensors, camera, products, alerts);
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Phone / narrow layout: a single full-width scrolling column.
  Widget _phoneBody(SensorData sensors, CameraConfig camera,
      List<Product> products, List<Alert> alerts) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: <Widget>[
        _Esp32Card(sensors: sensors),
        const SizedBox(height: 14),
        const _SectionTitle('Environment'),
        _SensorGrid(sensors: sensors),
        const SizedBox(height: 16),
        const _SectionTitle('Camera'),
        _CameraPreview(camera: camera),
        const SizedBox(height: 16),
        _SectionTitle('Products (${products.length})'),
        _LatestProducts(products: products),
        const SizedBox(height: 16),
        _SectionTitle('Alerts (${alerts.length})'),
        _AlertSummary(alerts: alerts),
      ],
    );
  }

  /// Desktop / wide layout: status banner across the top, a full-width row
  /// of four big sensor cards, then the camera fills the remaining height
  /// with products and alerts stacked underneath — filling the page.
  Widget _desktopBody(BoxConstraints c, SensorData sensors,
      CameraConfig camera, List<Product> products, List<Alert> alerts) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Esp32Card(sensors: sensors),
          const SizedBox(height: 18),
          // Sensors: a full-width row of four large cards.
          const _SectionTitle('Environment'),
          _SensorGrid(
            sensors: sensors,
            crossAxisCount: 4,
            childAspectRatio: 2.4,
            large: true,
          ),
          const SizedBox(height: 16),
          // Camera fills the remaining vertical space; products and alerts
          // sit underneath it, so the page is filled with no empty bottom.
          const _SectionTitle('Camera'),
          Expanded(child: _CameraPreview(camera: camera, fill: true)),
          const SizedBox(height: 14),
          _SectionTitle('Products (${products.length})'),
          _LatestProducts(products: products),
          const SizedBox(height: 14),
          _SectionTitle('Alerts (${alerts.length})'),
          _AlertSummary(alerts: alerts),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _Esp32Card extends StatelessWidget {
  const _Esp32Card({required this.sensors});
  final SensorData sensors;

  @override
  Widget build(BuildContext context) {
    final bool online = sensors.isOnline;
    final Color color = StatusColors.online(online);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.10),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle),
              child: Icon(online ? Icons.cloud_done : Icons.cloud_off,
                  color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    online
                        ? 'ESP32 Sensor Board Online'
                        : 'ESP32 Sensor Board Offline',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    online
                        ? 'Live sensor data is up to date.'
                        : 'No sensor update for over 60 seconds.',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({
    required this.sensors,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.55,
    this.large = false,
  });
  final SensorData sensors;
  final int crossAxisCount;
  final double childAspectRatio;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final bool on = sensors.isOnline;
    final double gap = large ? 14 : 10;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      childAspectRatio: childAspectRatio,
      children: <Widget>[
        SensorCard(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: sensors.temperature.toStringAsFixed(1),
          unit: '°C',
          color: const Color(0xFF1976D2),
          enabled: on,
          large: large,
        ),
        SensorCard(
          icon: Icons.water_drop,
          label: 'Humidity',
          value: sensors.humidity.toStringAsFixed(0),
          unit: '%',
          color: const Color(0xFF0097A7),
          enabled: on,
          large: large,
        ),
        SensorCard(
          icon: Icons.air,
          label: 'Gas (MQ135)',
          value: sensors.gasValue.toStringAsFixed(0),
          unit: 'adc',
          color: const Color(0xFF7B1FA2),
          enabled: on,
          large: large,
        ),
        SensorCard(
          icon: Icons.scale,
          label: 'Weight',
          value: sensors.weight.toStringAsFixed(0),
          unit: 'g',
          color: const Color(0xFF5D4037),
          enabled: on,
          large: large,
        ),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.camera, this.fill = false});
  final CameraConfig camera;

  /// When true the preview fills its parent box (used by the desktop layout
  /// where the camera expands to fill the remaining height). Otherwise it
  /// keeps a 16:9 aspect ratio (phone layout).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (!camera.isConfigured) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.videocam_off, color: StatusColors.neutral),
          title: Text('Camera not configured'),
          subtitle: Text('Set the ESP32-CAM IP on the Camera tab.'),
        ),
      );
    }
    final Widget video = Container(
      color: Colors.black,
      child: CameraStream(
        streamUrl: camera.streamUrl,
        captureUrl: camera.captureUrl,
      ),
    );
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: fill
            ? SizedBox.expand(child: video)
            : AspectRatio(aspectRatio: 16 / 9, child: video),
      ),
    );
  }
}

class _LatestProducts extends StatelessWidget {
  const _LatestProducts({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inventory_2_outlined,
              color: StatusColors.neutral),
          title: Text('No products yet'),
          subtitle: Text('Scan a product QR code on the Camera tab.'),
        ),
      );
    }
    return Column(
      children: products
          .take(3)
          .map((Product p) => ProductCard(product: p))
          .toList(),
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.alerts});
  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: StatusColors.fresh),
          title: Text('No alerts'),
          subtitle: Text('Everything looks fine.'),
        ),
      );
    }
    return Column(
      children: alerts.take(4).map((Alert a) {
        final Color color = StatusColors.forSeverity(a.severity);
        return Card(
          child: ListTile(
            leading: Icon(StatusColors.iconForSeverity(a.severity),
                color: color),
            title: Text(a.message, style: const TextStyle(fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }
}
