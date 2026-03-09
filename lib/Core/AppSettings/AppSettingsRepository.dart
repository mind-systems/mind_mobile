import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mind/Core/AppSettings/IAppSettingsStorage.dart';

class AppSettingsRepository {
  static const List<String> supportedLocales = ['en', 'ru'];

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

  Future<ThemeMode> getTheme() async {
    final value = await _storage.getString(_themeKey);
    return _themeModeFromString(value);
  }

  Future<void> setTheme(ThemeMode mode) async {
    await _storage.setString(_themeKey, _themeModeToString(mode));
  }

  // --------------- Language ---------------

  Future<String> getLanguage() async {
    final value = await _storage.getString(_languageKey);
    return value ?? 'en';
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

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}
