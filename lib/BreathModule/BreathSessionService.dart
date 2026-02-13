import 'package:mind/BreathModule/BreathSessionDTOMapper.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';

class BreathSessionService implements IBreathSessionService {
  final BreathSessionNotifier notifier;

  BreathSessionService({required this.notifier});

  @override
  Future<BreathSessionDTO> getSession(String id) async {
    final session = await notifier.getById(id);
    if (session == null) {
      throw Exception('Session not found');
    }
    return BreathSessionDTOMapper.map(session);
  }
}
