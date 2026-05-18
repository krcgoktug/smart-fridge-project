import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 4 - Alerts. Shows the alerts the image analysis service publishes
/// to Firebase.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<List<Alert>>(
        stream: FirebaseService.alertsStream(),
        builder: (BuildContext context, AsyncSnapshot<List<Alert>> snap) {
          final List<Alert> alerts = snap.data ?? <Alert>[];
          if (alerts.isEmpty) {
            return const _NoAlerts();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: alerts.length,
            itemBuilder: (BuildContext context, int i) {
              final Alert a = alerts[i];
              final Color color = StatusColors.forSeverity(a.severity);
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(StatusColors.iconForSeverity(a.severity),
                        color: color),
                  ),
                  title: Text(a.message),
                  subtitle: Text(
                    <String>[
                      a.severity.toUpperCase(),
                      if (a.type.isNotEmpty) a.type,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
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
          Text('No expiring products, sensor or banana issues right now.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
