import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';

abstract class IBreathSessionService {
  Future<BreathSessionDTO> getSession(String id);
}
