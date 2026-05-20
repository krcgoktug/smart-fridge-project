/// ESP32-CAM connection info, stored under `devices/fridge_01/camera`.
///
/// The camera IP is configured by the user in the app (each ESP32-CAM gets
/// its own local IP from the Wi-Fi router). Storing it in Firebase lets every
/// team member's app use the same address.
class CameraConfig {
  CameraConfig({
    this.localIp = '',
    this.lastSeenAt = 0,
  });

  final String localIp; // e.g. 192.168.1.44  (or a full http URL)
  final num lastSeenAt; // Unix seconds of the last successful connection

  bool get isConfigured => localIp.isNotEmpty;

  /// Normalised base URL, e.g. `http://192.168.1.44`.
  String get baseUrl {
    if (localIp.isEmpty) return '';
    String s = localIp.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    return s.replaceAll(RegExp(r'/+$'), '');
  }

  /// Stream is on port 81 so it cannot block /capture (which stays on port 80).
  String get streamUrl => localIp.isEmpty ? '' : '$baseUrl:81/stream';
  String get captureUrl => localIp.isEmpty ? '' : '$baseUrl/capture';

  factory CameraConfig.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return CameraConfig();
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return CameraConfig(
      localIp: (map['localIp'] ?? '').toString(),
      lastSeenAt: n(map['lastSeenAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'localIp': localIp,
        'streamUrl': streamUrl,
        'captureUrl': captureUrl,
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
}
