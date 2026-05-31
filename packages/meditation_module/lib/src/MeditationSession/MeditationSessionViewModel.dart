import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Models/MeditationSessionState.dart';

final meditationSessionViewModelProvider =
    NotifierProvider<MeditationSessionViewModel, MeditationSessionState>(() {
  throw UnimplementedError('must be overridden via ProviderScope');
});

class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  final _stateController = StreamController<MeditationSessionState>.broadcast();

  Stream<MeditationSessionState> get stream => _stateController.stream;

  @override
  MeditationSessionState build() {
    ref.onDispose(() => _stateController.close());
    return const MeditationSessionState.initial();
  }

  @override
  set state(MeditationSessionState value) {
    super.state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }

  void start() => state = state.copyWith(status: MeditationSessionStatus.active);
  void stop() => state = state.copyWith(status: MeditationSessionStatus.idle);
}
