import 'package:rxdart/rxdart.dart';
import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/User/Models/AuthState.dart';
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
    final expiry = userNotifier.stream
        .where((s) => s is GuestState)
        .map((_) => ProfileSessionExpired() as ProfileEvent)
        .take(1);
    final loaded = userNotifier.stream
        .where((s) => s is! GuestState)
        .map((s) => ProfileLoaded(user: UserDTO(name: s.user.name)) as ProfileEvent);
    return expiry.mergeWith([loaded]);
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
    final previous = appSettingsNotifier.currentState.language;
    await appSettingsNotifier.setLanguage(key);
    try {
      await userNotifier.updateLanguage(key);
    } catch (_) {
      await appSettingsNotifier.setLanguage(previous);
      rethrow;
    }
  }

  @override
  Future<void> updateName(String name) async {
    await userNotifier.updateName(name);
  }
}
