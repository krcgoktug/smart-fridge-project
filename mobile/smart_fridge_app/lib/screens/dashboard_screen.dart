import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/banana_analysis.dart';
import '../models/sensor_data.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';
import '../widgets/sensor_card.dart';

/// Screen 1 - Dashboard. ESP32 status, live sensors, banana analysis, alerts.
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
    // Re-evaluate the ESP32 offline timeout even with no new data.
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
      appBar: AppBar(title: const Text('Smart Fridge')),
      body: StreamBuilder<SensorData>(
        stream: FirebaseService.sensorStream(),
        builder: (BuildContext context, AsyncSnapshot<SensorData> sSnap) {
          final SensorData sensors = sSnap.data ?? SensorData();
          return StreamBuilder<BananaAnalysis>(
            stream: FirebaseService.bananaAnalysisStream(),
            builder: (BuildContext context,
                AsyncSnapshot<BananaAnalysis> bSnap) {
              final BananaAnalysis banana = bSnap.data ?? BananaAnalysis();
              return StreamBuilder<List<Alert>>(
                stream: FirebaseService.alertsStream(),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Alert>> aSnap) {
                  final List<Alert> alerts = aSnap.data ?? <Alert>[];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    children: <Widget>[
                      _Esp32Card(sensors: sensors),
                      const SizedBox(height: 14),
                      const _SectionTitle('Environment'),
                      if (sensors.isOnline)
                        _SensorGrid(sensors: sensors)
                      else
                        const _OfflineNotice(),
                      const SizedBox(height: 16),
                      const _SectionTitle('Banana analysis'),
                      _BananaCard(banana: banana),
                      const SizedBox(height: 16),
                      _SectionTitle('Alerts (${alerts.length})'),
                      _AlertList(alerts: alerts),
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
    final Color color = online ? StatusColors.fresh : StatusColors.danger;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.10),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(online ? Icons.cloud_done : Icons.cloud_off,
                  color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(online ? 'ESP32 Online' : 'ESP32 Offline',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(
                    online
                        ? 'Sensor heartbeat is up to date.'
                        : 'No sensor heartbeat for over 60 seconds.',
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

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFDECEA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.sensors_off, color: StatusColors.danger),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ESP32 Offline — temperature, weight and gas readings are '
                'not available right now.',
                style: TextStyle(fontSize: 13, height: 1.4),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: <Widget>[
        SensorCard(
          icon: Icons.scale,
          label: 'Weight',
          value: sensors.weight.toStringAsFixed(0),
          unit: 'g',
          color: const Color(0xFF5D4037),
        ),
        SensorCard(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: sensors.temperature.toStringAsFixed(1),
          unit: '°C',
          color: const Color(0xFF1976D2),
        ),
        SensorCard(
          icon: Icons.air,
          label: 'Gas (MQ135)',
          value: sensors.gas.toStringAsFixed(0),
          unit: 'adc',
          color: const Color(0xFF7B1FA2),
        ),
      ],
    );
  }
}

class _BananaCard extends StatelessWidget {
  const _BananaCard({required this.banana});
  final BananaAnalysis banana;

  @override
  Widget build(BuildContext context) {
    if (!banana.hasData) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.local_florist, color: StatusColors.neutral),
          title: Text('No banana analysis yet'),
          subtitle: Text('The image analysis service writes a result after '
              'each cycle.'),
        ),
      );
    }
    final Color color = StatusColors.forBananaStatus(banana.visualStatus);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.local_florist, color: color),
                const SizedBox(width: 8),
                Text('Browning: ${banana.brownPercent.toStringAsFixed(1)} %',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(banana.visualStatus,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (banana.brownPercent / 100).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.black12,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text('Recommendation: ${banana.status}',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(banana.message,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});
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
        return Card(
          child: ListTile(
            leading: Icon(StatusColors.iconForSeverity(a.severity),
                color: StatusColors.forSeverity(a.severity)),
            title: Text(a.message, style: const TextStyle(fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }
}
