/// Camera endpoint URLs published under `/devices/<id>/camera`.
class CameraInfo {
  CameraInfo({this.streamUrl, this.captureUrl});

  final String? streamUrl;
  final String? captureUrl;

  bool get hasUrls => captureUrl != null && captureUrl!.isNotEmpty;

  factory CameraInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return CameraInfo();
    return CameraInfo(
      streamUrl: map['streamUrl']?.toString(),
      captureUrl: map['captureUrl']?.toString(),
    );
  }
}
