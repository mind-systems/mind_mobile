import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;

import 'ClockTickService.dart';
import 'HeartRateTickService.dart';

class SwitchableTickService implements ITickService {
  SwitchableTickService({
    required ClockTickService clock,
    required HeartRateTickService heart,
  })  : _clock = clock,
        _heart = heart {
    _activeSource = TickSource.timer;
    _activeSub = _clock.tickStream.listen(_tickController.add);
    _healthSub = _heart.hasActiveSourceStream.listen((hasActive) {
      if (!hasActive && _activeSource == TickSource.heartbeat) {
        _switchInternal(TickSource.timer);
      }
    });
  }

  final ClockTickService _clock;
  final HeartRateTickService _heart;

  final StreamController<TickData> _tickController =
      StreamController<TickData>.broadcast();
  final StreamController<TickSource> _sourceChangesController =
      StreamController<TickSource>.broadcast();

  late TickSource _activeSource;
  StreamSubscription<TickData>? _activeSub;
  StreamSubscription<bool>? _healthSub;

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => _activeSource;

  @override
  Stream<TickSource> get sourceChanges => _sourceChangesController.stream;

  @override
  bool trySwitchTo(TickSource target) {
    if (target == _activeSource) return true;
    if (target == TickSource.heartbeat && !_heart.hasActiveSource) {
      return false;
    }
    _switchInternal(target);
    return true;
  }

  void _switchInternal(TickSource target) {
    _activeSub?.cancel();
    _activeSource = target;
    final ITickService next = target == TickSource.timer ? _clock : _heart;
    _activeSub = next.tickStream.listen(_tickController.add);
    _sourceChangesController.add(target);
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _healthSub?.cancel();
    _tickController.close();
    _sourceChangesController.close();
    _clock.dispose();
    _heart.dispose();
  }
}
