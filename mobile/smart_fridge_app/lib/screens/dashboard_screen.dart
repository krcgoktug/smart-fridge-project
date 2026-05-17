import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/firebase_service.dart';
import '../services/risk_service.dart';
import '../utils/status_colors.dart';
import '../widgets/firebase_notice.dart';
import '../widgets/sensor_card.dart';
import '../widgets/status_badge.dart';
import 'add_product_screen.dart';

/// Screen 1 - Dashboard. Live sensors, global risk, camera, latest alerts.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Fridge')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const AddProductScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Add Product'),
      ),
      body: FirebaseService.ready
          ? const _DashboardBody()
          : const FirebaseNotice(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SensorData>(
      stream: FirebaseService.sensorStream(),
      builder: (BuildContext context, AsyncSnapshot<SensorData> sensorSnap) {
        final SensorData sensors = sensorSnap.data ?? SensorData();
        return StreamBuilder<List<Product>>(
          stream: FirebaseService.productsStream(),
          builder: (BuildContext context,
              AsyncSnapshot<List<Product>> productSnap) {
            final List<Product> products = productSnap.data ?? <Product>[];
            // Recompute each product's risk against the current sensors.
            for (final Product p in products) {
              RiskService.applyToProduct(p, sensors);
            }
            final int globalScore =
                RiskService.globalScore(products, sensors);
            final String globalStatus =
                RiskService.statusFromScore(globalScore);

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              children: <Widget>[
                _GlobalRiskCard(
                  score: globalScore,
                  status: globalStatus,
                  productCount: products.length,
                ),
                const SizedBox(height: 8),
                const _SectionTitle('Environment'),
                _SensorGrid(sensors: sensors),
                const SizedBox(height: 16),
                const _SectionTitle('Camera'),
                const _CameraPreviewCard(),
                const SizedBox(height: 16),
                const _SectionTitle('Latest alerts'),
                const _LatestAlerts(),
              ],
            );
          },
        );
      },
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _GlobalRiskCard extends StatelessWidget {
  const _GlobalRiskCard({
    required this.score,
    required this.status,
    required this.productCount,
  });

  final int score;
  final String status;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final Color color = StatusColors.forScore(score);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.10),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            RiskScoreCircle(score: score, size: 86),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Global status',
                      style: TextStyle(
                          fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  StatusBadge(status: status),
                  const SizedBox(height: 10),
                  Text(
                    '$productCount product(s) monitored',
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
    final List<Widget> cards = <Widget>[
      SensorCard(
        icon: Icons.thermostat,
        label: 'Temperature',
        value: sensors.temperature.toStringAsFixed(1),
        unit: '°C',
        color: const Color(0xFF1976D2),
      ),
      SensorCard(
        icon: Icons.water_drop,
        label: 'Humidity',
        value: sensors.humidity.toStringAsFixed(0),
        unit: '%',
        color: const Color(0xFF0097A7),
      ),
      SensorCard(
        icon: Icons.air,
        label: 'Gas (MQ135)',
        value: sensors.gasValue.toStringAsFixed(0),
        unit: 'adc',
        color: const Color(0xFF7B1FA2),
      ),
      SensorCard(
        icon: Icons.scale,
        label: 'Total weight',
        value: sensors.weight.toStringAsFixed(0),
        unit: 'g',
        color: const Color(0xFF5D4037),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}

class _CameraPreviewCard extends StatelessWidget {
  const _CameraPreviewCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraInfo>(
      stream: FirebaseService.cameraStream(),
      builder: (BuildContext context, AsyncSnapshot<CameraInfo> snap) {
        final CameraInfo cam = snap.data ?? CameraInfo();
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: cam.hasUrls
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            cam.captureUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.videocam_off,
                                color: Colors.black38),
                          ),
                        )
                      : const Icon(Icons.videocam_off,
                          color: Colors.black38),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('ESP32-CAM',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        cam.hasUrls
                            ? cam.captureUrl!
                            : 'No camera URL published yet',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LatestAlerts extends StatelessWidget {
  const _LatestAlerts();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Alert>>(
      stream: FirebaseService.alertsStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Alert>> snap) {
        final List<Alert> alerts = snap.data ?? <Alert>[];
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
          children: alerts.take(3).map((Alert a) {
            return Card(
              child: ListTile(
                leading: Icon(
                  StatusColors.iconForSeverity(a.severity),
                  color: StatusColors.forSeverity(a.severity),
                ),
                title: Text(a.message, style: const TextStyle(fontSize: 14)),
                subtitle: Text(a.severity.toUpperCase(),
                    style: const TextStyle(fontSize: 11)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
