import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/banana_analysis.dart';
import '../models/camera_config.dart';
import '../models/product.dart';
import '../services/banana_analysis_service.dart';
import '../services/banana_state.dart';
import '../services/camera_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import '../utils/status_colors.dart';
// Conditional import: web uses an HTML <img>, mobile/desktop uses flutter_mjpeg.
import '../widgets/camera_stream_web.dart'
    if (dart.library.io) '../widgets/camera_stream_io.dart';

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

  // Auto-scan: periodically pull a frame, decode QR, register on success.
  Timer? _autoScanTimer;
  bool _autoScanning = false;

  // Product IDs already registered this session. Each QR sticker in the box
  // is read exactly once; re-seeing it on later frames is ignored so we
  // don't spam saves/snackbars. (Saves are idempotent anyway since the
  // productId is the storage key.)
  final Set<String> _registeredQrIds = <String>{};

  // Auto-add a "Banana (visual)" product whenever the camera sees a banana.
  // We only re-save when the freshness status changes, to avoid spamming the
  // products stream every 1.5 s.
  String? _lastBananaStatusSaved;

  @override
  void initState() {
    super.initState();
    _activeIp = SettingsService.cameraIp;
    _ipController = TextEditingController(text: _activeIp);
    if (_activeIp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _testConnection());
    }
    // Auto-scan every 1.5 s while the screen is open.
    _autoScanTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _autoScanTick(),
    );
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
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
    final Set<String> codes = CameraService.decodeQrCodes(bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _capturedImage = bytes;
      _online = true;
    });
    if (codes.isEmpty) {
      _snack('No QR code found in the camera frame.', StatusColors.warning);
      return;
    }
    int added = 0;
    int skipped = 0;
    for (final String qr in codes) {
      final Product? product = _parseProduct(qr);
      if (product == null) continue;
      if (_registeredQrIds.contains(product.productId)) {
        skipped++;
        continue;
      }
      await FirebaseService.saveProduct(product);
      _registeredQrIds.add(product.productId);
      added++;
    }
    if (added == 0 && skipped == 0) {
      _snack('QR code is not a valid product code.', StatusColors.danger);
    } else if (added == 0) {
      _snack('Already registered ($skipped).', StatusColors.warning);
    } else {
      _snack('Registered $added product(s) from QR.', StatusColors.fresh);
    }
  }

  /// Silent periodic scan that runs BOTH jobs on the same captured frame:
  ///   1. banana browning colour analysis (every cycle)
  ///   2. multi-QR registration — every distinct sticker in the box is read
  ///      once. No error popups; one success snackbar per newly added item.
  Future<void> _autoScanTick() async {
    if (_autoScanning || _busy || _testing) return;
    if (_activeIp.isEmpty) return;
    _autoScanning = true;
    try {
      final Uint8List? bytes =
          await CameraService.captureImage(_config.captureUrl);
      if (bytes == null) return;

      // 1) Banana browning analysis (runs every cycle, always).
      final BananaAnalysis banana =
          BananaAnalysisService.analyzeBytes(bytes);
      BananaState.update(banana);
      await _upsertBananaProduct(banana);

      // 2) Multi-QR scan: register each NEW product exactly once.
      final Set<String> codes = CameraService.decodeQrCodes(bytes);
      for (final String qr in codes) {
        final Product? product = _parseProduct(qr);
        if (product == null) continue;
        if (_registeredQrIds.contains(product.productId)) continue;
        await FirebaseService.saveProduct(product);
        _registeredQrIds.add(product.productId);
        if (mounted) {
          _snack('Added: ${product.name}', StatusColors.fresh);
        }
      }
    } catch (_) {
      // ignore; auto-scan is best-effort
    } finally {
      _autoScanning = false;
    }
  }

  /// Upserts a "Banana (visual)" product based on the live camera analysis.
  /// Only re-saves when the freshness band changes so we don't spam the
  /// products stream every auto-scan tick.
  Future<void> _upsertBananaProduct(BananaAnalysis b) async {
    if (!b.detected) return;
    if (b.status == _lastBananaStatusSaved) return;

    // Map the visual status to an estimated remaining shelf-life.
    int daysLeft;
    switch (b.status) {
      case 'Fresh':
        daysLeft = 5;
        break;
      case 'Spotting':
        daysLeft = 3;
        break;
      case 'Spoiling':
        daysLeft = 0;
        break;
      case 'Spoiled':
        daysLeft = -1;
        break;
      default:
        return;
    }

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expiry = today.add(Duration(days: daysLeft));

    final Product banana = Product(
      productId: 'banana_visual',
      name: 'Banana (visual)',
      category: 'Fruit',
      expiryDate: fmt(expiry),
      addedDate: fmt(today),
    );

    await FirebaseService.saveProduct(banana);
    _lastBananaStatusSaved = b.status;
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
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return c.maxWidth >= 720 ? _desktopBody() : _phoneBody();
            },
          );
        },
      ),
    );
  }

  /// Phone / narrow layout: a single full-width scrolling column.
  Widget _phoneBody() {
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
        const SizedBox(height: 12),
        const _BananaCard(),
        if (_capturedImage != null) ...<Widget>[
          const SizedBox(height: 12),
          _capturedCard(),
        ],
        const SizedBox(height: 12),
        _helpCard(),
      ],
    );
  }

  /// Desktop / wide layout: two columns that use the screen width.
  /// Left = live stream + capture/scan; right = address, status, banana
  /// analysis and help. Capped at a comfortable max width and centered.
  Widget _desktopBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Column(
                  children: <Widget>[
                    _streamCard(),
                    const SizedBox(height: 14),
                    _actionButtons(),
                    if (_capturedImage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _capturedCard(),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: Column(
                  children: <Widget>[
                    _ipCard(),
                    const SizedBox(height: 14),
                    _statusCard(),
                    const SizedBox(height: 14),
                    const _BananaCard(),
                    const SizedBox(height: 14),
                    _helpCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      child = CameraStream(
        streamUrl: _config.streamUrl,
        captureUrl: _config.captureUrl,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2E7D32)),
                SizedBox(width: 6),
                Text('Auto-scan is ON',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Just hold a product QR code in front of the camera — it will '
              'be registered automatically within ~1.5 s. Use the Scan QR '
              'button for an immediate manual scan.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            SizedBox(height: 6),
            Text(
              'The ESP32-CAM stream is on the local network — this phone/PC '
              'must share the same Wi-Fi as the camera.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
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

/// Live banana browning analysis result. Refreshes every auto-scan cycle.
class _BananaCard extends StatelessWidget {
  const _BananaCard();

  static Color _statusColor(String s) {
    switch (s) {
      case 'Fresh':
        return StatusColors.fresh;
      case 'Spotting':
        return StatusColors.warning;
      case 'Spoiling':
        return const Color(0xFFE65100); // orange
      case 'Spoiled':
        return StatusColors.danger;
      default:
        return StatusColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BananaAnalysis>(
      stream: BananaState.stream(),
      builder: (BuildContext context,
          AsyncSnapshot<BananaAnalysis> snap) {
        final BananaAnalysis b = snap.data ?? BananaAnalysis.empty();
        final Color color = _statusColor(b.status);
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.eco, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    const Text('Banana browning',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(b.status,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!b.detected)
                  const Text(
                    'No banana visible in the frame. Place a yellow banana '
                    'in front of the camera to start the analysis.',
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.black54),
                  )
                else ...<Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Spot coverage'),
                      Text('${b.spotPercent.toStringAsFixed(1)} %',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:
                          (b.spotPercent / 100).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusHint(b.status, b.spotPercent),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _statusHint(String status, double pct) {
    switch (status) {
      case 'Fresh':
        return 'Healthy banana — under 20 % spots.';
      case 'Spotting':
        return 'Light spotting — still fine to eat.';
      case 'Spoiling':
        return 'Spoilage started — consume soon.';
      case 'Spoiled':
        return 'Heavily spoiled — discard.';
      default:
        return '';
    }
  }
}
