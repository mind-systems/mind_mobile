import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';

abstract class IProfileService {
  String get appVersion;
  Stream<ProfileEvent> observeProfile();
}
