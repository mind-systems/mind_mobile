import 'dart:io';

import 'package:mind/Core/AppSettings/IAppSettingsStorage.dart';

class AppSettingsRepository {
  static const List<String> supportedLocales = ['en', 'ru'];
  static const List<String> supportedThemes = ['system', 'dark', 'light'];

  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';

  final IAppSettingsStorage _storage;

  AppSettingsRepository(this._storage);

  /// Called once on startup. Detects locale from platform if not yet stored.
  Future<void> init() async {
    final stored = await _storage.getString(_languageKey);
    if (stored == null) {
      final detected = resolveLocale(Platform.localeName);
      await _storage.setString(_languageKey, detected);
    }
  }

  // --------------- Theme ---------------

  Future<String> getTheme() async {
    return await _storage.getString(_themeKey) ?? 'system';
  }

  Future<void> setTheme(String key) async {
    await _storage.setString(_themeKey, key);
  }

  // --------------- Language ---------------

  Future<String> getLanguage() async {
    return await _storage.getString(_languageKey) ?? 'en';
  }

  Future<void> setLanguage(String languageCode) async {
    await _storage.setString(_languageKey, languageCode);
  }

  // --------------- Helpers ---------------

  /// Resolves a platform locale string to a supported language code.
  /// Handles both iOS format ('en-US') and Android format ('en_US').
  /// Returns 'en' if no match is found.
  String resolveLocale(String platformLocale) {
    // Normalise separator: Android uses '_', iOS uses '-' → unify to '-'
    final normalised = platformLocale.replaceAll('_', '-');
    final tag = normalised.toLowerCase();

    // Exact match on language subtag
    for (final code in supportedLocales) {
      if (tag == code || tag.startsWith('$code-')) {
        return code;
      }
    }

    return 'en';
  }
}
