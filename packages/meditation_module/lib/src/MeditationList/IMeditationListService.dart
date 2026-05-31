import '../Models/MeditationPoses.dart';

abstract class IMeditationListService {
  List<MeditationPoseDTO> poses();
}
