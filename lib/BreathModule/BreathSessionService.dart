import 'package:mind/BreathModule/BreathSessionDTOMapper.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:breath_module/breath_module.dart' show IBreathSessionService, BreathSessionDTO;
import 'package:mind/User/UserNotifier.dart';

class BreathSessionService implements IBreathSessionService {
  final BreathSessionNotifier notifier;
  final UserNotifier userNotifier;

  BreathSessionService({required this.notifier, required this.userNotifier});

  String get _currentUserId => userNotifier.currentUser.id;

  @override
  Future<BreathSessionDTO> getSession(String id) async {
    final session = await notifier.getById(id);
    if (session == null) {
      throw Exception('Session not found');
    }
    return BreathSessionDTOMapper.map(session, currentUserId: _currentUserId);
  }

  @override
  Stream<BreathSessionDTO> observeSession(String id) {
    return notifier.stream
        .skip(1) // skip BehaviorSubject replay — we already loaded via getSession()
        .expand((state) {
      final event = state.lastEvent;
      if (event is SessionUpdated && event.session.id == id) {
        return [BreathSessionDTOMapper.map(event.session, currentUserId: _currentUserId)];
      }
      return [];
    });
  }

  @override
  Stream<void> observeSessionDeletion(String id) {
    return notifier.stream
        .skip(1)
        .expand((state) {
      final event = state.lastEvent;
      if (event is SessionDeleted && event.id == id) return [null];
      return [];
    });
  }

  @override
  Future<BreathSessionDTO> starSession(String id, {required bool starred}) async {
    await notifier.starSession(id, starred: starred);
    final session = await notifier.getById(id);
    if (session == null) {
      throw Exception('Session not found');
    }
    return BreathSessionDTOMapper.map(session, currentUserId: _currentUserId);
  }
}
