import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData;

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
