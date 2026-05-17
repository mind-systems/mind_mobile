import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;

class ClockTickService implements ITickService {
  final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();
  Timer? _timer;

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => TickSource.timer;

  void simulateTick() {
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _tickController.add(TickData(const Duration(milliseconds: 1000).inMilliseconds));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickController.close();
  }
}
