import 'package:mind/BreathModule/Core/LiveSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/ILiveSessionService.dart';

class LiveSessionService implements ILiveSessionService {
  final LiveSessionNotifier _notifier;

  LiveSessionService({required LiveSessionNotifier notifier}) : _notifier = notifier;

  @override
  void startSession(String sessionId) {
    _notifier.start('breath_session', sessionId);
  }

  @override
  void endSession() {
    _notifier.end();
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
  Stream<LiveSessionDto> get sessionStateStream {
    return _notifier.stream.map((state) => LiveSessionDto(
      liveSessionId: state.liveSessionId,
      isActive: state.status == LiveSessionStatus.active,
      isPaused: state.isPaused,
    ));
  }
}
