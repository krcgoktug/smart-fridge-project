import 'dart:async';

import '../models/banana_analysis.dart';

/// Process-wide in-app pubsub for the latest banana analysis. The Camera
/// screen writes here on every analysis cycle; the Dashboard reads from it.
class BananaState {
  BananaState._();

  static BananaAnalysis _latest = BananaAnalysis.empty();
  static final StreamController<BananaAnalysis> _ctrl =
      StreamController<BananaAnalysis>.broadcast();

  static BananaAnalysis get latest => _latest;

  static Stream<BananaAnalysis> stream() async* {
    yield _latest;
    yield* _ctrl.stream;
  }

  static void update(BananaAnalysis a) {
    _latest = a;
    _ctrl.add(a);
  }
}
