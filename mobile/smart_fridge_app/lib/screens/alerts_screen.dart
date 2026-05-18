import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/camera_config.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/alert_service.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 4 - Alerts. Expiry warnings, ESP32 offline, camera offline.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Timer? _timer;
  CameraConfig _camera = CameraConfig();
  bool _cameraOnline = true;

  @override
  void initState() {
    super.initState();
    // Periodically re-check the ESP32 timeout and the camera reachability.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkCamera();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkCamera() async {
    if (!_camera.isConfigured) {
      _cameraOnline = true;
      return;
    }
    final bool ok = await CameraService.testConnection(_camera.captureUrl);
    if (mounted) setState(() => _cameraOnline = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
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
                  final CameraConfig camera = cSnap.data ?? CameraConfig();
                  if (camera.localIp != _camera.localIp) {
                    _camera = camera;
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _checkCamera());
                  }
                  final List<Alert> alerts = AlertService.derive(
                    sensors: sensors,
                    products: products,
                    cameraConfigured: camera.isConfigured,
                    cameraOnline: _cameraOnline,
                  );
                  if (alerts.isEmpty) {
                    return const _NoAlerts();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: alerts.length,
                    itemBuilder: (BuildContext context, int i) {
                      final Alert a = alerts[i];
                      final Color color =
                          StatusColors.forSeverity(a.severity);
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                color.withValues(alpha: 0.15),
                            child: Icon(
                                StatusColors.iconForSeverity(a.severity),
                                color: color),
                          ),
                          title: Text(a.message),
                          subtitle: Text(a.type.toUpperCase(),
                              style: const TextStyle(fontSize: 11)),
                        ),
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
}

class _NoAlerts extends StatelessWidget {
  const _NoAlerts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 60, color: Colors.black26),
          SizedBox(height: 12),
          Text('No alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('No expiring products, sensor or camera issues right now.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
