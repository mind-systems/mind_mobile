import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:breath_module/breath_module.dart' show ILiveBreathSessionService, LiveBreathSessionDto;

class LiveBreathSessionService implements ILiveBreathSessionService {
  final ModuleStateChannel _channel;

  LiveBreathSessionService({required ModuleStateChannel channel}) : _channel = channel;

  @override
  void startSession(String sessionId) {
    _channel.start(type: ActivityType.breath, refId: sessionId);
  }

  @override
  void endSession() {
    _channel.end();
  }

  @override
  void stopSession() {
    _channel.stop();
  }

  @override
  void pauseSession() {
    _channel.pause();
  }

  @override
  void resumeSession() {
    _channel.unpause();
  }

  @override
  Stream<LiveBreathSessionDto> get sessionStateStream {
    return _channel.state.map((state) => LiveBreathSessionDto(
      liveSessionId: state.liveSessionId,
      isActive: state.status == ModuleStateStatus.active,
      isPaused: state.isPaused,
    ));
  }
}
