import 'package:mind/BreathModule/Core/LiveBreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionState.dart';
import 'package:breath_module/breath_module.dart' show ILiveBreathSessionService, LiveBreathSessionDto;

class LiveBreathSessionService implements ILiveBreathSessionService {
  final LiveBreathSessionNotifier _notifier;

  LiveBreathSessionService({required LiveBreathSessionNotifier notifier}) : _notifier = notifier;

  @override
  void startSession(String sessionId) {
    _notifier.start('breath_session', 'breath_session', sessionId);
  }

  @override
  void endSession() {
    _notifier.end();
  }

  @override
  void stopSession() {
    _notifier.stop();
  }

  @override
  void pauseSession() {
    _notifier.pause();
  }

  @override
  void resumeSession() {
    _notifier.unpause();
  }

  @override
  Stream<LiveBreathSessionDto> get sessionStateStream {
    return _notifier.stream.map((state) => LiveBreathSessionDto(
      liveSessionId: state.liveSessionId,
      isActive: state.status == LiveBreathSessionStatus.active,
      isPaused: state.isPaused,
    ));
  }
}
