import 'dart:async';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:meditation_module/meditation_module.dart' show MeditationSessionState, MeditationSessionStatus;

class MeditationModuleStateChannel {
  final ModuleStateChannel _channel;
  final String _refId;
  bool _started = false;
  bool _ended = false;
  MeditationSessionStatus? _previousStatus;
  String? _moduleSessionId;
  late final StreamSubscription<MeditationSessionState> _stateSub;
  late final StreamSubscription<ModuleState> _channelSub;
  late final StreamSubscription<ModuleStateEvent> _eventsSub;

  MeditationModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<MeditationSessionState> stateStream,
    required String refId,
  })  : _channel = channel,
        _refId = refId {
    _stateSub = stateStream.listen(_onState);
    _channelSub = channel.state.listen((moduleState) {
      if (moduleState.moduleSessionId != null) {
        _moduleSessionId = moduleState.moduleSessionId;
      }
    });
    _eventsSub = channel.events.listen((event) {
      if (event is ModuleSessionAbandoned) {
        _started = false;
        _ended = false;
        _moduleSessionId = null;
        _previousStatus = null;
      }
    });
  }

  String? get moduleSessionId => _moduleSessionId;

  void _onState(MeditationSessionState state) {
    final status = state.status;
    if (status == _previousStatus) return;

    if (status == MeditationSessionStatus.active && !_started) {
      _channel.start(type: ActivityType.meditation, refId: _refId, clientTimestampMs: DateTime.now().millisecondsSinceEpoch);
      _started = true;
    } else if (status == MeditationSessionStatus.idle && _started && !_ended) {
      _channel.end(clientTimestampMs: DateTime.now().millisecondsSinceEpoch);
      // Re-arm so the next Start→Stop cycle fires fresh lifecycle events.
      // Mirrors BreathModuleStateChannel.reset() (BreathModuleStateChannel.dart:137-148).
      _started = false;
      _ended = false;
    }
    _previousStatus = status;
  }

  void dispose() {
    if (_started && !_ended) _channel.stop();
    _stateSub.cancel();
    _channelSub.cancel();
    _eventsSub.cancel();
  }
}
