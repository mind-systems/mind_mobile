import 'package:flutter/material.dart';
import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
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
  List<String> get themeOptions => ['System', 'Dark', 'Light'];

  @override
  List<String> get languageOptions => ['English', 'Русский'];

  @override
  String get currentThemeLabel => _themeLabelFromMode(appSettingsNotifier.currentState.theme);

  @override
  String get currentLanguageLabel => _languageLabelFromLocale(appSettingsNotifier.currentState.locale);

  @override
  Future<void> updateTheme(String label) async {
    await appSettingsNotifier.setTheme(_themeModeFromLabel(label));
  }

  @override
  Future<void> updateLanguage(String label) async {
    await appSettingsNotifier.setLanguage(_languageCodeFromLabel(label));
  }

  ThemeMode _themeModeFromLabel(String label) {
    switch (label) {
      case 'Dark':
        return ThemeMode.dark;
      case 'Light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  String _languageCodeFromLabel(String label) {
    switch (label) {
      case 'Русский':
        return 'ru';
      default:
        return 'en';
    }
  }

  String _themeLabelFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _languageLabelFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ru':
        return 'Русский';
      default:
        return 'English';
    }
  }
}
