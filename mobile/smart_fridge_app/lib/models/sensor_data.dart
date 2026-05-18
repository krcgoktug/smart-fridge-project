/// Latest sensor heartbeat from the ESP32 DevKit, read from
/// `devices/<id>/sensors`.
class SensorData {
  SensorData({
    this.weight = 0,
    this.temperature = 0,
    this.humidity = 0,
    this.gas = 0,
    this.updatedAt = 0,
    this.alive = false,
  });

  final num weight; // grams
  final num temperature; // Celsius
  final num humidity; // percent (DHT11)
  final num gas; // MQ135 raw ADC
  final num updatedAt; // Unix seconds (NTP)
  final bool alive;

  /// True when a heartbeat exists at all.
  bool get hasData => updatedAt > 0;

  /// The ESP32 is online when the heartbeat is fresh (< 60 s old).
  bool get isOnline {
    if (!hasData || !alive) return false;
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
      weight: n(map['weight']),
      temperature: n(map['temperature']),
      humidity: n(map['humidity']),
      gas: n(map['gas']),
      updatedAt: n(map['updatedAt']),
      alive: map['alive'] == true,
    );
  }
}
