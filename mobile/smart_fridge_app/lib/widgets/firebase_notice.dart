import 'package:flutter/material.dart';

/// Shown on data screens when Firebase has not been configured yet
/// (placeholder `firebase_options.dart`). Keeps the app usable instead of
/// crashing.
class FirebaseNotice extends StatelessWidget {
  const FirebaseNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 56, color: Colors.black38),
            const SizedBox(height: 16),
            const Text(
              'Firebase not configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The app is running with placeholder Firebase settings.\n'
              'Run "flutterfire configure" to generate '
              'lib/firebase_options.dart for your own project, '
              'then restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
