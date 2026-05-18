import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';

/// Screen 5 - Settings. ESP32-CAM address, connection info, hardware notes.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _camController;

  @override
  void initState() {
    super.initState();
    _camController =
        TextEditingController(text: SettingsService.cameraBaseUrl);
  }

  @override
  void dispose() {
    _camController.dispose();
    super.dispose();
  }

  Future<void> _saveCamera() async {
    await SettingsService.setCameraBaseUrl(_camController.text);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Camera address saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = FirebaseService.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // --- ESP32-CAM address ---
          _Card(
            title: 'ESP32-CAM address',
            children: <Widget>[
              const Text(
                'Enter the camera IP / URL, e.g. http://192.168.1.50. Used '
                'for the live stream on the Camera screen.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _camController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Camera IP / URL',
                        hintText: 'http://192.168.1.50',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: _saveCamera, child: const Text('Save')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                SettingsService.streamUrl.isEmpty
                    ? 'Stream URL: (not set)'
                    : 'Stream URL: ${SettingsService.streamUrl}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),

          // --- Hardware mode note ---
          const Card(
            color: Color(0xFFFFF3CD),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Hardware Mode (live ESP32-CAM stream) requires the Android '
                'app or a local Flutter run on the same Wi-Fi. The GitHub '
                'Pages site is HTTPS, so browsers block the HTTP camera '
                'stream — it is a UI demo only.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ),

          // --- Connection ---
          _Card(
            title: 'Connection',
            children: <Widget>[
              _Row(
                label: 'Firebase',
                value: ready ? 'Configured' : 'Not configured',
                valueColor:
                    ready ? StatusColors.fresh : StatusColors.danger,
              ),
              const _Row(label: 'Device ID', value: AppConfig.deviceId),
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

          // --- Architecture ---
          const _Card(
            title: 'Architecture',
            children: <Widget>[
              _Row(label: 'Sensor node', value: 'ESP32 DevKit V1'),
              _Row(label: 'Camera node', value: 'ESP32-CAM AI-Thinker'),
              _Row(label: 'Processing', value: 'Python backend (QR + CV)'),
              _Row(label: 'This app', value: 'Read-only dashboard'),
            ],
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Zero Waste Smart Fridge  -  v1.0.0',
                style: TextStyle(color: Colors.black45, fontSize: 12)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            width: 120,
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
