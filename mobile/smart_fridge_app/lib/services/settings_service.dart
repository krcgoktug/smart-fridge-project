import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-configurable ESP32-CAM address.
///
/// The camera IP is never hard-coded — the user enters it on the Settings
/// screen. It is used only to display the live MJPEG stream.
class SettingsService {
  static const String _kCameraBaseUrl = 'cameraBaseUrl';

  static SharedPreferences? _prefs;
  static String _cameraBaseUrl = '';

  /// Load persisted settings. Call once at startup.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cameraBaseUrl = _prefs?.getString(_kCameraBaseUrl) ?? '';
    } catch (_) {
      _cameraBaseUrl = '';
    }
  }

  /// The ESP32-CAM base address, e.g. `http://192.168.1.50`. Empty if unset.
  static String get cameraBaseUrl => _cameraBaseUrl;

  static Future<void> setCameraBaseUrl(String value) async {
    _cameraBaseUrl = value.trim();
    await _prefs?.setString(_kCameraBaseUrl, _cameraBaseUrl);
  }

  static String _base() => _cameraBaseUrl.replaceAll(RegExp(r'/+$'), '');

  /// MJPEG stream URL, or '' when the address is not set.
  static String get streamUrl =>
      _cameraBaseUrl.isEmpty ? '' : '${_base()}/stream';

  /// Single-frame snapshot URL, or '' when the address is not set.
  static String get captureUrl =>
      _cameraBaseUrl.isEmpty ? '' : '${_base()}/capture';
}
