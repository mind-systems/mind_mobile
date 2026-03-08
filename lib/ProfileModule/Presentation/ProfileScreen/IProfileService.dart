import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';

abstract class IProfileService {
  Future<String> get appVersion;
  Stream<ProfileEvent> observeProfile();
}
