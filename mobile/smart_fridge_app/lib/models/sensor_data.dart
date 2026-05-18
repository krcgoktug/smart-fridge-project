/// Live sensor values from the ESP32 DevKit, read from
/// `devices/fridge_01/sensors`.
class SensorData {
  SensorData({
    this.temperature = 0,
    this.humidity = 0,
    this.gasValue = 0,
    this.weight = 0,
    this.updatedAt = 0,
  });

  final num temperature; // Celsius
  final num humidity; // percent
  final num gasValue; // MQ135 raw ADC
  final num weight; // grams
  final num updatedAt; // Unix seconds

  /// True when a reading exists at all.
  bool get hasData => updatedAt > 0;

  /// The ESP32 board is considered online when the last update is < 60 s old.
  bool get isOnline {
    if (!hasData) return false;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - updatedAt) <= 60;
  }

  factory SensorData.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return SensorData();
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return SensorData(
      temperature: n(map['temperature']),
      humidity: n(map['humidity']),
      gasValue: n(map['gasValue']),
      weight: n(map['weight']),
      updatedAt: n(map['updatedAt']),
    );
  }
}
