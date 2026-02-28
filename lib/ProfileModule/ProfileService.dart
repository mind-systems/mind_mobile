import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/User/UserNotifier.dart';

class ProfileService implements IProfileService {
  final UserNotifier userNotifier;
  @override
  final String appVersion;

  ProfileService({required this.userNotifier, required this.appVersion});

  @override
  Stream<ProfileEvent> observeProfile() {
    return userNotifier.stream.map((authState) =>
        ProfileLoaded(user: UserDTO(name: authState.user.name)));
  }
}
