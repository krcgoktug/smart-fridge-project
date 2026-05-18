import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of the ESP32-CAM address.
///
/// The shared camera config lives in Firebase (`devices/fridge_01/camera`).
/// This local copy just lets the Camera screen pre-fill the input instantly
/// before the Firebase value arrives.
class SettingsService {
  static const String _kCameraIp = 'cameraIp';

  static SharedPreferences? _prefs;
  static String _cameraIp = '';

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cameraIp = _prefs?.getString(_kCameraIp) ?? '';
    } catch (_) {
      _cameraIp = '';
    }
  }

  static String get cameraIp => _cameraIp;

  static Future<void> setCameraIp(String value) async {
    _cameraIp = value.trim();
    await _prefs?.setString(_kCameraIp, _cameraIp);
  }
}
