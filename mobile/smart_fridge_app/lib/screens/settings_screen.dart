import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';

/// Screen 7 - Settings / Firebase config info.
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
            title: 'Connection',
            children: <Widget>[
              _Row(
                label: 'Firebase',
                value: ready ? 'Configured' : 'Not configured',
                valueColor:
                    ready ? StatusColors.fresh : StatusColors.spoilage,
              ),
              const _Row(label: 'Device ID', value: AppConfig.deviceId),
              _Row(
                  label: 'Database path',
                  value: '/${AppConfig.deviceRoot}'),
            ],
          ),
          if (!ready)
            const Card(
              color: Color(0xFFFDECEA),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Firebase is using placeholder settings. Generate your '
                  'own config by running:\n\n'
                  '    flutterfire configure\n\n'
                  'This creates lib/firebase_options.dart. Restart the app '
                  'afterwards.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
          const _CameraConfigCard(),
          const _Card(
            title: 'Hardware',
            children: <Widget>[
              _Row(label: 'Box dimensions',
                  value: AppConfig.boxDimensions),
              _Row(label: 'Sensor node', value: 'ESP32 DevKit V1 (optional)'),
              _Row(label: 'Camera node', value: 'ESP32-CAM AI-Thinker'),
              _Row(
                  label: 'Sensors',
                  value: 'DHT11, MQ135, HX711 (optional)'),
            ],
          ),
          const _Card(
            title: 'Risk model',
            children: <Widget>[
              _Row(label: 'Fresh', value: 'score 0 - 39'),
              _Row(label: 'Consume Soon', value: 'score 40 - 69'),
              _Row(label: 'Spoilage Risk', value: 'score 70 - 100'),
            ],
          ),
          const _Card(
            title: 'Database structure',
            children: <Widget>[
              _Row(label: 'sensors', value: 'temp, humidity, gas, weight'),
              _Row(label: 'camera', value: 'streamUrl, captureUrl'),
              _Row(label: 'products', value: 'QR product data'),
              _Row(label: 'bananaAnalysis', value: 'browning percentages'),
              _Row(label: 'alerts', value: 'notifications'),
            ],
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Zero Waste Smart Fridge  -  v1.0.0',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable ESP32-CAM address. The IP is never hard-coded — the user sets
/// it here and it is persisted via SettingsService.
class _CameraConfigCard extends StatefulWidget {
  const _CameraConfigCard();

  @override
  State<_CameraConfigCard> createState() => _CameraConfigCardState();
}

class _CameraConfigCardState extends State<_CameraConfigCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: SettingsService.cameraBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await SettingsService.setCameraBaseUrl(_controller.text);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Camera address saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final String capture = SettingsService.configuredCaptureUrl;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('ESP32-CAM address',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 18),
            const Text(
              'Enter the camera IP or URL (e.g. http://192.168.1.50). '
              'Leave blank to use the URL the ESP32-CAM publishes to '
              'Firebase. In Demo mode bundled sample images are used.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
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
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              capture.isEmpty
                  ? 'Effective capture URL: (from Firebase / not set)'
                  : 'Effective capture URL: $capture',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
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
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
