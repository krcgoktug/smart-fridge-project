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
  static const String _localhostFallback = 'http://localhost:8787';

  /// Returns a stream of live sensor readings polled from [baseUrl].
  ///
  /// On every tick it first tries the configured URL; if that fails (e.g.
  /// the user kept a stale LAN IP in Settings after their laptop got a new
  /// DHCP address), it transparently falls back to `http://localhost:8787`
  /// so the app keeps working when the bridge runs on the same machine as
  /// the browser.
  static Stream<SensorData> stream(String baseUrl) {
    final String url = _normalize(baseUrl);
    if (url.isEmpty) {
      return Stream<SensorData>.value(SensorData());
    }

    late final StreamController<SensorData> ctrl;
    Timer? timer;
    bool busy = false;
    // After the first successful poll we stick to whichever URL worked,
    // so a stale configured URL doesn't cost a 2 s timeout on every
    // cycle. Reset to null on a hard failure so we re-probe.
    String? stickyHost;

    Future<bool> tryFetch(String base) async {
      try {
        final http.Response r = await http
            .get(Uri.parse('$base/sensors'))
            .timeout(_httpTimeout);
        if (r.statusCode != 200) return false;
        final dynamic decoded = jsonDecode(r.body);
        if (decoded is! Map) return false;
        ctrl.add(SensorData.fromMap(
          decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        ));
        return true;
      } catch (_) {
        return false;
      }
    }

    Future<void> poll() async {
      // Don't overlap polls (a stalled request must not pile up new ones).
      if (busy) return;
      busy = true;
      try {
        // Fast path: keep using the URL we already know works.
        if (stickyHost != null) {
          if (await tryFetch(stickyHost!)) return;
          stickyHost = null; // it died; re-probe below
        }
        // Probe: configured URL first, localhost as the safety net.
        if (await tryFetch(url)) {
          stickyHost = url;
          return;
        }
        if (url != _localhostFallback) {
          if (await tryFetch(_localhostFallback)) {
            stickyHost = _localhostFallback;
          }
        }
      } finally {
        busy = false;
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

  /// Tells the Python bridge to send a "t" command to the Arduino, which
  /// re-tares the HX711 load cell to zero. Falls back to localhost if the
  /// configured URL doesn't answer (same logic as the sensor stream).
  /// Returns true when the bridge accepted the command.
  static Future<bool> tare(String baseUrl) async {
    final String url = _normalize(baseUrl);
    Future<bool> tryOne(String base) async {
      if (base.isEmpty) return false;
      try {
        final http.Response r = await http
            .post(Uri.parse('$base/tare'))
            .timeout(_httpTimeout);
        return r.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
    if (await tryOne(url)) return true;
    if (url != _localhostFallback) {
      return tryOne(_localhostFallback);
    }
    return false;
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
