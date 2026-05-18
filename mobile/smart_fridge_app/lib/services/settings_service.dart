import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-configurable settings — currently the ESP32-CAM address.
///
/// The camera IP is never hard-coded: the user sets it on the Settings
/// screen. When it is left blank the app falls back to the `captureUrl`
/// the ESP32-CAM publishes to Firebase.
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

  /// The user-configured ESP32-CAM base address, e.g. `http://192.168.1.50`.
  /// Empty when not set.
  static String get cameraBaseUrl => _cameraBaseUrl;

  static Future<void> setCameraBaseUrl(String value) async {
    _cameraBaseUrl = value.trim();
    await _prefs?.setString(_kCameraBaseUrl, _cameraBaseUrl);
  }

  /// The `/capture` URL derived from [cameraBaseUrl], or '' when not set.
  static String get configuredCaptureUrl {
    if (_cameraBaseUrl.isEmpty) return '';
    final String base = _cameraBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return base.endsWith('/capture') ? base : '$base/capture';
  }

  /// Resolve the capture URL to use: the user-configured value wins,
  /// otherwise the URL published by the ESP32-CAM to Firebase.
  static String resolveCaptureUrl(String? firebaseCaptureUrl) {
    final String configured = configuredCaptureUrl;
    if (configured.isNotEmpty) return configured;
    return firebaseCaptureUrl ?? '';
  }
}
