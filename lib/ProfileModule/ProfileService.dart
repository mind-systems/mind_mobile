import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileService implements IProfileService {
  final UserNotifier userNotifier;
  final AppSettingsNotifier appSettingsNotifier;

  ProfileService({
    required this.userNotifier,
    required this.appSettingsNotifier,
  });

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

  @override
  List<String> get themeOptions => AppSettingsRepository.supportedThemes;

  @override
  List<String> get languageOptions => AppSettingsRepository.supportedLocales;

  @override
  String get currentTheme => appSettingsNotifier.currentState.theme;

  @override
  String get currentLanguage => appSettingsNotifier.currentState.language;

  @override
  Future<void> updateTheme(String key) async {
    await appSettingsNotifier.setTheme(key);
  }

  @override
  Future<void> updateLanguage(String key) async {
    await appSettingsNotifier.setLanguage(key);
  }
}
