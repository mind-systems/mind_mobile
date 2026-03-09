import 'package:mind/Core/AppSettings/IAppSettingsStorage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage implements IAppSettingsStorage {
  final SharedPreferences _prefs;

  SharedPreferencesStorage(this._prefs);

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
}
