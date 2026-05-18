import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/camera_config.dart';
import '../services/firebase_service.dart';
import '../utils/status_colors.dart';

/// Screen 5 - Settings. Firebase info, camera IP, hardware-mode notes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool ready = FirebaseService.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Card(
            title: 'Firebase',
            children: <Widget>[
              _Row(
                label: 'Status',
                value: ready ? 'Connected' : 'Not configured',
                valueColor:
                    ready ? StatusColors.fresh : StatusColors.danger,
              ),
              const _Row(label: 'Device ID', value: AppConfig.deviceId),
              const _Row(
                  label: 'Database path', value: 'devices/fridge_01'),
            ],
          ),
          if (!ready)
            const Card(
              color: Color(0xFFFDECEA),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Firebase is using placeholder settings, so no live data '
                  'is shown. Run "flutterfire configure" to connect a real '
                  'project, then restart the app.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
          StreamBuilder<CameraConfig>(
            stream: FirebaseService.cameraStream(),
            builder:
                (BuildContext context, AsyncSnapshot<CameraConfig> snap) {
              final CameraConfig cam = snap.data ?? CameraConfig();
              return _Card(
                title: 'Camera',
                children: <Widget>[
                  _Row(
                    label: 'ESP32-CAM IP',
                    value: cam.isConfigured ? cam.localIp : 'Not set',
                  ),
                  _Row(
                    label: 'Stream URL',
                    value:
                        cam.isConfigured ? cam.streamUrl : '-',
                  ),
                  const _Row(
                    label: 'Change it',
                    value: 'Use the Camera tab to set the IP.',
                  ),
                ],
              );
            },
          ),
          const _Card(
            title: 'Hardware mode — how the network works',
            children: <Widget>[
              _Note(
                'Sensor data (temperature, humidity, gas, weight), products '
                'and alerts go through Firebase. Every team member sees them '
                'live — even though the ESP32 is plugged into just one PC.',
              ),
              SizedBox(height: 8),
              _Note(
                'The ESP32-CAM live stream is on the LOCAL network. Only a '
                'phone/PC on the SAME Wi-Fi as the camera can view '
                'http://CAMERA_IP/stream.',
              ),
            ],
          ),
          const _Card(
            title: 'About',
            children: <Widget>[
              _Row(label: 'App', value: 'Zero Waste Smart Fridge'),
              _Row(label: 'Version', value: '1.0.0'),
              _Row(label: 'Devices', value: 'ESP32 DevKit + ESP32-CAM'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12.5, color: Colors.black87, height: 1.4));
  }
}
