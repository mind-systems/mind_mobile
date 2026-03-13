import 'package:mind/BreathModule/BreathSessionDTOMapper.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
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
  Future<BreathSessionDTO> starSession(String id, {required bool starred}) async {
    await notifier.starSession(id, starred: starred);
    final session = await notifier.getById(id);
    if (session == null) {
      throw Exception('Session not found');
    }
    return BreathSessionDTOMapper.map(session, currentUserId: _currentUserId);
  }
}
