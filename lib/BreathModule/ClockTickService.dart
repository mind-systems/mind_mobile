import 'dart:async';

import 'package:mind/BreathModule/ITickService.dart';

class ClockTickService implements ITickService {
  final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  void simulateTick() {
    Timer.periodic(Duration(milliseconds: 1000), (timer) {
      _tickController.add(
        TickData(Duration(milliseconds: 1000).inMilliseconds),
      );
    });
  }
}
