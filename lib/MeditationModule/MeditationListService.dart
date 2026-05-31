import 'package:meditation_module/meditation_module.dart';

class MeditationListService implements IMeditationListService {
  @override
  List<MeditationPoseDTO> poses() => kMeditationPoses;
}
