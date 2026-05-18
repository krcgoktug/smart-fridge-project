import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../models/camera_config.dart';
import '../models/product.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';

/// Screen 2 - Camera. Configure the ESP32-CAM IP, view the live stream,
/// test the connection, capture a frame and scan product QR codes.
class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  late final TextEditingController _ipController;

  String _activeIp = '';
  bool _adoptedFromCloud = false;

  bool? _online; // null = not tested yet
  bool _testing = false;
  bool _busy = false;
  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();
    _activeIp = SettingsService.cameraIp;
    _ipController = TextEditingController(text: _activeIp);
    if (_activeIp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _testConnection());
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  CameraConfig get _config => CameraConfig(localIp: _activeIp);

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _saveIp() async {
    final String ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _snack('Enter the ESP32-CAM IP first.', StatusColors.danger);
      return;
    }
    setState(() {
      _activeIp = ip;
      _capturedImage = null;
      _online = null;
    });
    await SettingsService.setCameraIp(ip);
    await FirebaseService.saveCameraConfig(CameraConfig(localIp: ip));
    _snack('Camera IP saved.', StatusColors.fresh);
    await _testConnection();
  }

  Future<void> _testConnection() async {
    if (_activeIp.isEmpty) return;
    setState(() => _testing = true);
    final bool ok = await CameraService.testConnection(_config.captureUrl);
    if (!mounted) return;
    setState(() {
      _online = ok;
      _testing = false;
    });
    if (ok) {
      await FirebaseService.saveCameraConfig(CameraConfig(localIp: _activeIp));
    } else {
      _snack(
        'Camera unavailable. Make sure the ESP32-CAM and this device are '
        'connected to the same Wi-Fi/network.',
        StatusColors.danger,
      );
    }
  }

  Future<void> _capture() async {
    if (_activeIp.isEmpty) {
      _snack('Save the camera IP first.', StatusColors.danger);
      return;
    }
    setState(() => _busy = true);
    final Uint8List? bytes =
        await CameraService.captureImage(_config.captureUrl);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _capturedImage = bytes;
      _online = bytes != null;
    });
    if (bytes == null) {
      _snack(
        'Camera unavailable. Make sure the ESP32-CAM and this device are '
        'connected to the same Wi-Fi/network.',
        StatusColors.danger,
      );
    }
  }

  Future<void> _scanQr() async {
    if (_activeIp.isEmpty) {
      _snack('Save the camera IP first.', StatusColors.danger);
      return;
    }
    setState(() => _busy = true);
    final Uint8List? bytes =
        await CameraService.captureImage(_config.captureUrl);
    if (bytes == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _online = false;
      });
      _snack(
        'Camera unavailable. Make sure the ESP32-CAM and this device are '
        'connected to the same Wi-Fi/network.',
        StatusColors.danger,
      );
      return;
    }
    final String? qr = CameraService.decodeQr(bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _capturedImage = bytes;
      _online = true;
    });
    if (qr == null) {
      _snack('No QR code found in the camera frame.', StatusColors.warning);
      return;
    }
    final Product? product = _parseProduct(qr);
    if (product == null) {
      _snack('QR code is not a valid product code.', StatusColors.danger);
      return;
    }
    await FirebaseService.saveProduct(product);
    _snack('${product.name} registered from QR code.', StatusColors.fresh);
  }

  Product? _parseProduct(String qrText) {
    try {
      final dynamic decoded = jsonDecode(qrText);
      if (decoded is! Map) return null;
      final Map<String, dynamic> m =
          decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
      final String id = (m['productId'] ?? '').toString();
      final String name = (m['name'] ?? '').toString();
      if (id.isEmpty || name.isEmpty) return null;
      return Product(
        productId: id,
        name: name,
        category: (m['category'] ?? 'Other').toString(),
        expiryDate: (m['expiryDate'] ?? '').toString(),
        addedDate: (m['addedDate'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: StreamBuilder<CameraConfig>(
        stream: FirebaseService.cameraStream(),
        builder: (BuildContext context, AsyncSnapshot<CameraConfig> snap) {
          // Adopt the team's shared camera IP once, if we have none yet.
          final CameraConfig cloud = snap.data ?? CameraConfig();
          if (!_adoptedFromCloud &&
              _activeIp.isEmpty &&
              cloud.isConfigured) {
            _adoptedFromCloud = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeIp = cloud.localIp;
                _ipController.text = cloud.localIp;
              });
              _testConnection();
            });
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: <Widget>[
              _ipCard(),
              const SizedBox(height: 12),
              _statusCard(),
              const SizedBox(height: 12),
              _streamCard(),
              const SizedBox(height: 12),
              _actionButtons(),
              if (_capturedImage != null) ...<Widget>[
                const SizedBox(height: 12),
                _capturedCard(),
              ],
              const SizedBox(height: 12),
              _helpCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _ipCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('ESP32-CAM address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'Enter the local IP shown on the ESP32-CAM Serial Monitor. '
              'Every camera gets its own IP from the Wi-Fi router.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Camera IP / URL',
                      hintText: '172.19.15.112',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveIp(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _saveIp, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final bool online = _online == true;
    final Color color = _online == null
        ? StatusColors.neutral
        : StatusColors.online(online);
    final String text = _online == null
        ? 'Connection not tested yet'
        : (online ? 'Camera Online' : 'Camera Offline');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(online ? Icons.videocam : Icons.videocam_off, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color)),
            ),
            OutlinedButton.icon(
              onPressed: _testing || _activeIp.isEmpty
                  ? null
                  : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: const Text('Test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streamCard() {
    Widget child;
    if (_activeIp.isEmpty) {
      child = const _StreamMessage(
          'Enter and save the ESP32-CAM IP to see the live stream.');
    } else {
      child = Mjpeg(
        key: ValueKey<String>(_config.streamUrl),
        stream: _config.streamUrl,
        isLive: true,
        fit: BoxFit.contain,
        error: (BuildContext context, dynamic e, dynamic s) =>
            const _StreamMessage(
          'Camera unavailable. Make sure the ESP32-CAM and this device '
          'are connected to the same Wi-Fi/network.',
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(color: Colors.black, child: child),
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _capture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : _scanQr,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46)),
          ),
        ),
      ],
    );
  }

  Widget _capturedCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Last captured frame',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Image.memory(_capturedImage!, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _helpCard() {
    return Card(
      color: const Color(0xFFEFF4EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'The ESP32-CAM stream is on the local network. This phone/PC must '
          'be on the SAME Wi-Fi as the camera to view it. Sensor data, '
          'products and alerts go through Firebase and are visible to all '
          'team members anywhere.',
          style: TextStyle(fontSize: 12.5, color: Colors.black87),
        ),
      ),
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
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}
