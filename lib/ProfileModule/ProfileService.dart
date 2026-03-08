import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileService implements IProfileService {
  final UserNotifier userNotifier;

  ProfileService({required this.userNotifier});

  @override
  Future<String> get appVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  @override
  Stream<ProfileEvent> observeProfile() {
    return userNotifier.stream.map(
      (authState) => ProfileLoaded(user: UserDTO(name: authState.user.name)),
    );
  }
}
