import 'dart:async';

import 'package:mind/BreathModule/ITickService.dart';

class ClockTickService implements ITickService {
  final StreamController<TickData> _tickController = StreamController<TickData>();

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  void simulateTick() {
    Timer.periodic(Duration(milliseconds: 2000), (timer) {
      _tickController.add(
        TickData(Duration(milliseconds: 2000).inMilliseconds),
      );
    });
  }
}
