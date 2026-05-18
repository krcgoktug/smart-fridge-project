/// A load-cell weight event written by the ESP32 DevKit to
/// `/devices/<id>/detection`.
///
/// When [newProductDetected] is true the app fetches the ESP32-CAM image,
/// decodes the QR code, registers the product, and then resets the flag.
class DetectionEvent {
  DetectionEvent({
    this.newProductDetected = false,
    this.eventType = 'none',
    this.weightDelta = 0,
    this.stableWeight = 0,
    this.updatedAt = 0,
  });

  /// True => a product was placed and needs automatic registration.
  final bool newProductDetected;

  /// "added" | "removed" | "none".
  final String eventType;

  /// Signed weight change in grams (positive = added, negative = removed).
  final num weightDelta;

  /// The stable total weight after the change, in grams.
  final num stableWeight;

  /// Unix seconds of the event (used to de-duplicate processing).
  final num updatedAt;

  bool get isAddition => eventType == 'added';
  bool get isRemoval => eventType == 'removed';

  factory DetectionEvent.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return DetectionEvent();
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return DetectionEvent(
      newProductDetected: map['newProductDetected'] == true,
      eventType: (map['eventType'] ?? 'none').toString(),
      weightDelta: n(map['weightDelta']),
      stableWeight: n(map['stableWeight']),
      updatedAt: n(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'newProductDetected': newProductDetected,
        'eventType': eventType,
        'weightDelta': weightDelta,
        'stableWeight': stableWeight,
        'updatedAt': updatedAt,
      };
}
