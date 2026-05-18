import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/product.dart';
import '../models/sensor_data.dart';
import '../services/alert_service.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 4 - Alerts. Alerts are derived on the device from the live data.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
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
              return StreamBuilder<BananaAnalysis>(
                stream: FirebaseService.bananaAnalysisStream(),
                builder: (BuildContext context,
                    AsyncSnapshot<BananaAnalysis> bSnap) {
                  final List<Alert> alerts = AlertService.derive(
                    sensors: sensors,
                    products: products,
                    banana: bSnap.data ?? BananaAnalysis(),
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
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(
                                StatusColors.iconForSeverity(a.severity),
                                color: color),
                          ),
                          title: Text(a.message),
                          subtitle: Text(a.severity.toUpperCase(),
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
          Icon(Icons.notifications_off_outlined,
              size: 60, color: Colors.black26),
          SizedBox(height: 12),
          Text('No alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('No expiring products or sensor issues right now.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
