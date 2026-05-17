/// Latest environmental readings written by the ESP32 DevKit sensor node
/// to `/devices/<id>/sensors`.
class SensorData {
  SensorData({
    this.temperature = 0,
    this.humidity = 0,
    this.gasValue = 0,
    this.weight = 0,
    this.riskScore = 0,
    this.status = 'Fresh',
    this.updatedAt = 0,
  });

  final num temperature; // Celsius
  final num humidity; // percent
  final num gasValue; // MQ135 raw ADC
  final num weight; // grams (total box weight)
  final num riskScore; // sensor-only risk estimate from firmware
  final String status;
  final num updatedAt; // seconds

  bool get isEmpty => updatedAt == 0;

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
      riskScore: n(map['riskScore']),
      status: (map['status'] ?? 'Fresh').toString(),
      updatedAt: n(map['updatedAt']),
    );
  }
}
