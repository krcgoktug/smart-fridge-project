import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of user-tweakable settings:
///   - ESP32-CAM address  (the team's shared copy lives in Firebase too)
///   - Arduino Uno serial bridge URL (the small Python script on the laptop)
class SettingsService {
  static const String _kCameraIp = 'cameraIp';
  static const String _kSensorBridgeUrl = 'sensorBridgeUrl';

  /// Default URL of the Python serial bridge when launched on the same
  /// machine that hosts the Flutter web app.
  static const String defaultSensorBridgeUrl = 'http://localhost:8787';

  static SharedPreferences? _prefs;
  static String _cameraIp = '';
  static String _sensorBridgeUrl = defaultSensorBridgeUrl;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cameraIp = _prefs?.getString(_kCameraIp) ?? '';
      _sensorBridgeUrl =
          _prefs?.getString(_kSensorBridgeUrl) ?? defaultSensorBridgeUrl;
    } catch (_) {
      _cameraIp = '';
      _sensorBridgeUrl = defaultSensorBridgeUrl;
    }
  }

  static String get cameraIp => _cameraIp;

  static Future<void> setCameraIp(String value) async {
    _cameraIp = value.trim();
    await _prefs?.setString(_kCameraIp, _cameraIp);
  }

  static String get sensorBridgeUrl => _sensorBridgeUrl;

  static Future<void> setSensorBridgeUrl(String value) async {
    _sensorBridgeUrl = value.trim();
    await _prefs?.setString(_kSensorBridgeUrl, _sensorBridgeUrl);
  }
}
