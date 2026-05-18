import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../models/alert.dart';
import '../models/camera_config.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';
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
                  final CameraConfig camera =
                      cSnap.data ?? CameraConfig();
                  final List<Alert> alerts = AlertService.derive(
                    sensors: sensors,
                    products: products,
                  );
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
                },
              );
            },
          );
        },
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
  const _SensorGrid({required this.sensors});
  final SensorData sensors;

  @override
  Widget build(BuildContext context) {
    final bool on = sensors.isOnline;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: <Widget>[
        SensorCard(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: sensors.temperature.toStringAsFixed(1),
          unit: '°C',
          color: const Color(0xFF1976D2),
          enabled: on,
        ),
        SensorCard(
          icon: Icons.water_drop,
          label: 'Humidity',
          value: sensors.humidity.toStringAsFixed(0),
          unit: '%',
          color: const Color(0xFF0097A7),
          enabled: on,
        ),
        SensorCard(
          icon: Icons.air,
          label: 'Gas (MQ135)',
          value: sensors.gasValue.toStringAsFixed(0),
          unit: 'adc',
          color: const Color(0xFF7B1FA2),
          enabled: on,
        ),
        SensorCard(
          icon: Icons.scale,
          label: 'Weight',
          value: sensors.weight.toStringAsFixed(0),
          unit: 'g',
          color: const Color(0xFF5D4037),
          enabled: on,
        ),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.camera});
  final CameraConfig camera;

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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Mjpeg(
              stream: camera.streamUrl,
              isLive: true,
              fit: BoxFit.contain,
              error: (BuildContext context, dynamic e, dynamic s) =>
                  const Center(
                child: Text('Camera preview unavailable',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            ),
          ),
        ),
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
