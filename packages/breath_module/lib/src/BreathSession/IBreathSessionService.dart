import 'Models/BreathSessionDTO.dart';

abstract class IBreathSessionService {
  Future<BreathSessionDTO> getSession(String id);
  Future<BreathSessionDTO> starSession(String id, {required bool starred});
  Stream<BreathSessionDTO> observeSession(String id);
}
