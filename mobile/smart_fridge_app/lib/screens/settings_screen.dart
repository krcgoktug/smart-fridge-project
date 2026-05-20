import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/camera_config.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';

/// Screen 5 - Settings. Firebase info, camera IP, Arduino sensor bridge.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _bridgeCtrl;

  @override
  void initState() {
    super.initState();
    _bridgeCtrl =
        TextEditingController(text: SettingsService.sensorBridgeUrl);
  }

  @override
  void dispose() {
    _bridgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBridge() async {
    final String url = _bridgeCtrl.text.trim().isEmpty
        ? SettingsService.defaultSensorBridgeUrl
        : _bridgeCtrl.text.trim();
    await SettingsService.setSensorBridgeUrl(url);
    if (!mounted) return;
    setState(() => _bridgeCtrl.text = url);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Arduino bridge URL saved.'),
        backgroundColor: StatusColors.fresh,
      ));
  }

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
              color: Color(0xFFFFF7E0),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Firebase is not configured. The app reads sensors directly '
                  'from the Arduino Uno through the local Python bridge below, '
                  'and keeps scanned products in an in-memory list.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
          _Card(
            title: 'Arduino Uno bridge (sensors)',
            children: <Widget>[
              const _Note(
                'The Arduino Uno has no Wi-Fi, so it connects to the laptop '
                'over USB. Start the helper:',
              ),
              const SizedBox(height: 6),
              const _Code('python bridge/arduino_serial_bridge.py'),
              const SizedBox(height: 10),
              TextField(
                controller: _bridgeCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Bridge URL',
                  hintText: 'http://localhost:8787',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _saveBridge(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saveBridge,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 4),
              const _Note(
                'Use http://localhost:8787 when the app and the bridge run on '
                'the same machine. Use http://<laptop-LAN-IP>:8787 when the '
                'app is on a phone/another PC.',
              ),
            ],
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
                'Sensors live on an Arduino Uno (DHT11, MQ135, HX711 load '
                'cells). The Uno talks JSON over USB to the laptop; a small '
                'Python script exposes the latest reading on '
                'http://localhost:8787/sensors and the app polls it.',
              ),
              SizedBox(height: 8),
              _Note(
                'The ESP32-CAM live stream is on the LOCAL Wi-Fi network. '
                'Only a phone/PC on the SAME Wi-Fi as the camera can view '
                'http://CAMERA_IP:81/stream.',
              ),
            ],
          ),
          const _Card(
            title: 'About',
            children: <Widget>[
              _Row(label: 'App', value: 'Zero Waste Smart Fridge'),
              _Row(label: 'Version', value: '1.0.0'),
              _Row(label: 'Devices', value: 'Arduino Uno + ESP32-CAM'),
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

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
      ),
    );
  }
}
