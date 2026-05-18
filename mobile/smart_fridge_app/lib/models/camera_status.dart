/// ESP32-CAM online status, read from `devices/<id>/camera`.
///
/// The camera never writes to Firebase — the image analysis service reports
/// whether it could reach the camera while pulling frames.
class CameraStatus {
  CameraStatus({
    this.online = false,
    this.ip = '',
    this.lastFrameAt = 0,
    this.frameWidth = 0,
    this.frameHeight = 0,
  });

  final bool online;
  final String ip;
  final num lastFrameAt; // Unix seconds
  final num frameWidth;
  final num frameHeight;

  /// True when the service has reported a status at least once.
  bool get hasData => lastFrameAt > 0 || ip.isNotEmpty;

  /// Resolution label, or '' when unknown.
  String get resolutionLabel =>
      (frameWidth > 0 && frameHeight > 0) ? '$frameWidth x $frameHeight' : '';

  factory CameraStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return CameraStatus();
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return CameraStatus(
      online: map['online'] == true,
      ip: (map['ip'] ?? '').toString(),
      lastFrameAt: n(map['lastFrameAt']),
      frameWidth: n(map['frameWidth']),
      frameHeight: n(map['frameHeight']),
    );
  }
}
