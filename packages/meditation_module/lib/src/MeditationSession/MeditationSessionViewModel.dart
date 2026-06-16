import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Models/MeditationSessionState.dart';

final meditationSessionViewModelProvider =
    NotifierProvider<MeditationSessionViewModel, MeditationSessionState>(() {
  throw UnimplementedError('must be overridden via ProviderScope');
});

class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  MeditationSessionViewModel({required this.poseId});

  final String poseId;
  final _stateController = StreamController<MeditationSessionState>.broadcast();
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  Timer? _timer;

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
    elapsedSeconds.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++);
    state = state.copyWith(status: MeditationSessionStatus.active);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(status: MeditationSessionStatus.idle);
  }
}
