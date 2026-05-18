import 'dart:async';

import 'package:flutter/material.dart';

import '../models/camera_info.dart';
import '../models/detection_event.dart';
import '../services/auto_registration_service.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Invisible widget that runs the **automatic product registration** flow for
/// the whole app.
///
/// It listens to the ESP32 DevKit's weight-detection events. When a product
/// is placed on the scale (`newProductDetected == true`), it triggers
/// [AutoRegistrationService] and shows the user a snackbar for each stage.
/// Place it once, high in the widget tree, wrapping the app content.
class AutoRegistrationListener extends StatefulWidget {
  const AutoRegistrationListener({super.key, required this.child});

  final Widget child;

  @override
  State<AutoRegistrationListener> createState() =>
      _AutoRegistrationListenerState();
}

class _AutoRegistrationListenerState extends State<AutoRegistrationListener> {
  StreamSubscription<DetectionEvent>? _detectionSub;
  StreamSubscription<CameraInfo>? _cameraSub;

  CameraInfo _camera = CameraInfo();

  // Rising-edge guard: handle each "newProductDetected" exactly once.
  bool _armed = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _cameraSub = FirebaseService.cameraStream().listen((CameraInfo c) {
      _camera = c;
    });
    _detectionSub =
        FirebaseService.detectionStream().listen(_onDetectionEvent);
  }

  @override
  void dispose() {
    _detectionSub?.cancel();
    _cameraSub?.cancel();
    super.dispose();
  }

  Future<void> _onDetectionEvent(DetectionEvent event) async {
    // Re-arm once the flag has been cleared.
    if (!event.newProductDetected) {
      _armed = true;
      return;
    }
    // Only additions trigger automatic registration.
    if (!event.isAddition || !_armed || _processing) return;

    _armed = false;
    _processing = true;
    _showSnack(
      'New product detected on the scale — registering...',
      StatusColors.neutral,
      icon: Icons.sensors,
    );

    final AutoRegistrationResult result =
        await AutoRegistrationService.register(event: event, camera: _camera);

    _processing = false;
    if (!mounted) return;

    switch (result.status) {
      case AutoRegStatus.success:
        _showSnack(
          'Registered automatically: ${result.product!.name}',
          StatusColors.fresh,
          icon: Icons.check_circle,
        );
        break;
      case AutoRegStatus.failure:
        _showSnack(
          'Auto-registration failed: ${result.message} '
          'Try the manual scan.',
          StatusColors.spoilage,
          icon: Icons.error_outline,
        );
        break;
      case AutoRegStatus.ignored:
        break;
    }
  }

  void _showSnack(String message, Color color, {required IconData icon}) {
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 4),
          content: Row(
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
