import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/alert.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 6 - Alerts.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const _AlertsBody(),
    );
  }
}

class _AlertsBody extends StatelessWidget {
  const _AlertsBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Alert>>(
      stream: FirebaseService.alertsStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Alert>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Alert> alerts = snap.data ?? <Alert>[];
        if (alerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.notifications_off_outlined,
                    size: 60, color: Colors.black26),
                SizedBox(height: 12),
                Text('No alerts',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Alerts appear here when products need attention.',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: alerts.length,
          itemBuilder: (BuildContext context, int i) {
            final Alert a = alerts[i];
            final Color color = StatusColors.forSeverity(a.severity);
            return Dismissible(
              key: ValueKey<String>(a.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: StatusColors.spoilage,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => FirebaseService.deleteAlert(a.id),
              child: Card(
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
                  subtitle: Text(
                    '${a.severity.toUpperCase()}  -  '
                    '${DateFormat('dd MMM, HH:mm').format(a.createdDateTime)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
