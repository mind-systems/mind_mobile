import 'dart:async';

import 'package:meditation_module/meditation_module.dart' show MeditationSessionState, MeditationSessionStatus;
import 'package:mind_audio/mind_audio.dart';

/// Starts and stops [SilentKeepAlivePlayer] in response to meditation session
/// status transitions, keeping the iOS audio session alive for the duration of
/// an active meditation.
class MeditationKeepAliveCoordinator {
  final SilentKeepAlivePlayer _player;
  MeditationSessionStatus? _previousStatus;
  late final StreamSubscription<MeditationSessionState> _stateSub;

  MeditationKeepAliveCoordinator({
    required Stream<MeditationSessionState> stateStream,
    required SilentKeepAlivePlayer player,
  }) : _player = player {
    _stateSub = stateStream.listen(_onState);
  }

  void _onState(MeditationSessionState state) {
    final status = state.status;
    if (status == _previousStatus) return;
    _previousStatus = status;

    if (status == MeditationSessionStatus.active) {
      _player.start();
    } else if (status == MeditationSessionStatus.idle) {
      _player.stop();
    }
  }

  void dispose() {
    _stateSub.cancel();
    _player.dispose();
  }
}
