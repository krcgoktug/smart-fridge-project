import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/camera_status.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';
import '../widgets/camera_stream_web.dart'
    if (dart.library.io) '../widgets/camera_stream_io.dart';

/// Screen 3 - Camera. Lets the user enter the ESP32-CAM address and shows
/// the live MJPEG stream plus the camera online status.
class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  late final TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController =
        TextEditingController(text: SettingsService.cameraBaseUrl);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await SettingsService.setCameraBaseUrl(_ipController.text);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
          const SnackBar(content: Text('Camera address saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final String streamUrl = SettingsService.streamUrl;
    // A web build served over HTTPS cannot load the camera's HTTP stream
    // (mixed content). A local HTTP run (flutter run -d chrome) is fine.
    final bool httpsBlocked = kIsWeb && Uri.base.scheme == 'https';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload stream',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _AddressCard(controller: _ipController, onSave: _save),
          const SizedBox(height: 14),
          if (httpsBlocked) ...<Widget>[
            const _HttpsBlockedNote(),
            const SizedBox(height: 14),
          ],
          StreamBuilder<CameraStatus>(
            stream: FirebaseService.cameraStatusStream(),
            builder:
                (BuildContext context, AsyncSnapshot<CameraStatus> snap) =>
                    _CameraStatusCard(status: snap.data ?? CameraStatus()),
          ),
          const SizedBox(height: 14),
          _StreamArea(streamUrl: streamUrl, httpsBlocked: httpsBlocked),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.controller, required this.onSave});

  final TextEditingController controller;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('ESP32-CAM address',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Enter the camera IP shown on the Arduino Serial Monitor. '
              'This device must be on the same Wi-Fi as the ESP32-CAM.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Camera IP / URL',
                      hintText: 'http://192.168.1.50',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSave(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSave,
                  child: const Text('Show'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraStatusCard extends StatelessWidget {
  const _CameraStatusCard({required this.status});
  final CameraStatus status;

  @override
  Widget build(BuildContext context) {
    final bool online = status.online;
    final Color color = online ? StatusColors.fresh : StatusColors.danger;
    final String detail;
    if (!status.hasData) {
      detail = 'The image analysis service has not reported the camera yet.';
    } else if (online) {
      final String res = status.resolutionLabel;
      detail = res.isEmpty
          ? 'The service is reading frames from the camera.'
          : 'The service is reading $res frames from the camera.';
    } else {
      detail = 'The image analysis service cannot reach the camera.';
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(online ? Icons.videocam : Icons.videocam_off,
            color: color),
        title: Text(online ? 'Camera Online' : 'Camera Offline',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _StreamArea extends StatelessWidget {
  const _StreamArea({required this.streamUrl, required this.httpsBlocked});

  final String streamUrl;
  final bool httpsBlocked;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (httpsBlocked) {
      child = const _StreamMessage(
        'The live stream is disabled on an HTTPS page.\n'
        'Run the app as the Android app or a local run on the same Wi-Fi.',
      );
    } else if (streamUrl.isEmpty) {
      child = const _StreamMessage(
        'Enter the ESP32-CAM IP above to view the live stream.',
      );
    } else {
      child = CameraStream(streamUrl: streamUrl);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: Colors.black, child: child),
          ),
        ),
        if (streamUrl.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('Stream: $streamUrl',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ],
    );
  }
}

class _StreamMessage extends StatelessWidget {
  const _StreamMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
      ),
    );
  }
}

class _HttpsBlockedNote extends StatelessWidget {
  const _HttpsBlockedNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3CD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: Color(0xFF8A6D00)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This page is served over HTTPS, so the browser blocks the '
                "ESP32-CAM's HTTP stream (mixed content). Use the Android "
                'app or a local run on the same Wi-Fi for the live camera.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF8A6D00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
