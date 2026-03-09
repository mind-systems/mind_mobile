import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';

abstract class IProfileService {
  Future<String> get appVersion;
  Stream<ProfileEvent> observeProfile();

  List<String> get themeOptions;
  List<String> get languageOptions;
  String get currentThemeLabel;
  String get currentLanguageLabel;
  Future<void> updateTheme(String label);
  Future<void> updateLanguage(String label);
}
