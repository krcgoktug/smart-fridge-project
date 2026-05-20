import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';

/// Polls the small Python bridge that reads the Arduino Uno over USB and
/// exposes the latest reading at `<baseUrl>/sensors` (typically
/// `http://localhost:8787`).
///
/// Returns a broadcast stream of [SensorData] so multiple screens can
/// listen at once. Empty [baseUrl] = stream a permanent "no data" value
/// (used when the user hasn't configured the bridge URL yet).
class LocalSensorBridge {
  LocalSensorBridge._();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _httpTimeout = Duration(seconds: 2);

  /// Returns a stream of live sensor readings polled from [baseUrl].
  static Stream<SensorData> stream(String baseUrl) {
    final String url = _normalize(baseUrl);
    if (url.isEmpty) {
      return Stream<SensorData>.value(SensorData());
    }

    late final StreamController<SensorData> ctrl;
    Timer? timer;

    Future<void> poll() async {
      try {
        final http.Response r = await http
            .get(Uri.parse('$url/sensors'))
            .timeout(_httpTimeout);
        if (r.statusCode != 200) return;
        final dynamic decoded = jsonDecode(r.body);
        if (decoded is! Map) return;
        ctrl.add(SensorData.fromMap(
          decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        ));
      } catch (_) {
        // bridge unreachable - keep the previous "online" state until the
        // 60 s timeout in SensorData.isOnline expires
      }
    }

    ctrl = StreamController<SensorData>.broadcast(
      onListen: () {
        // emit a "no data yet" tick immediately, then poll
        ctrl.add(SensorData());
        poll();
        timer = Timer.periodic(_pollInterval, (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return ctrl.stream;
  }

  static String _normalize(String s) {
    String t = s.trim();
    if (t.isEmpty) return '';
    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      t = 'http://$t';
    }
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }
}
