import 'dart:async';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:meditation_module/meditation_module.dart' show MeditationSessionState, MeditationSessionStatus;

class MeditationModuleStateChannel {
  final ModuleStateChannel _channel;
  final String _poseId;
  bool _started = false;
  bool _ended = false;
  MeditationSessionStatus? _previousStatus;
  late final StreamSubscription<MeditationSessionState> _stateSub;

  MeditationModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<MeditationSessionState> stateStream,
    required String poseId,
  })  : _channel = channel,
        _poseId = poseId {
    _stateSub = stateStream.listen(_onState);
  }

  void _onState(MeditationSessionState state) {
    final status = state.status;
    if (status == _previousStatus) return;

    if (status == MeditationSessionStatus.active && !_started) {
      _channel.start(type: ActivityType.meditation, refId: _poseId);
      _started = true;
    } else if (status == MeditationSessionStatus.idle && _started && !_ended) {
      _channel.end();
      // Re-arm so the next Start→Stop cycle fires fresh lifecycle events.
      // Mirrors BreathModuleStateChannel.reset() (BreathModuleStateChannel.dart:110-113).
      _started = false;
      _ended = false;
    }
    _previousStatus = status;
  }

  void dispose() {
    if (_started && !_ended) _channel.stop();
    _stateSub.cancel();
  }
}
