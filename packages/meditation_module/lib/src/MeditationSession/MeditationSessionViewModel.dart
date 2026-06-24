import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Models/MeditationSessionState.dart';

final meditationSessionViewModelProvider =
    NotifierProvider<MeditationSessionViewModel, MeditationSessionState>(() {
  throw UnimplementedError('must be overridden via ProviderScope');
});

class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  MeditationSessionViewModel({
    required this.poseId,
    DateTime Function() clock = DateTime.now,
    Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,
  })  : _clock = clock,
        _timerFactory = timerFactory;

  final String poseId;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function(Timer)) _timerFactory;
  final _stateController = StreamController<MeditationSessionState>.broadcast();
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  Timer? _timer;
  DateTime? _startedAt;

  Stream<MeditationSessionState> get stream => _stateController.stream;

  @override
  MeditationSessionState build() {
    ref.onDispose(() {
      _stateController.close();
      _timer?.cancel();
      elapsedSeconds.dispose();
    });
    return MeditationSessionState.initial(poseId: poseId);
  }

  @override
  set state(MeditationSessionState value) {
    super.state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }

  void start() {
    _startedAt = _clock();
    elapsedSeconds.value = 0;
    _timer = _timerFactory(const Duration(seconds: 1), (_) {
      elapsedSeconds.value = _clock().difference(_startedAt!).inSeconds;
    });
    state = state.copyWith(status: MeditationSessionStatus.active);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    state = state.copyWith(status: MeditationSessionStatus.idle);
  }
}
