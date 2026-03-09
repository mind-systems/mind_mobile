import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';

abstract class IProfileService {
  Future<String> get appVersion;
  Stream<ProfileEvent> observeProfile();

  List<String> get themeOptions;
  List<String> get languageOptions;
  String get currentTheme;
  String get currentLanguage;
  Future<void> updateTheme(String key);
  Future<void> updateLanguage(String key);
}
