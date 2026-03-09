import 'package:flutter/material.dart';

class AppSettingsState {
  final ThemeMode theme;
  final Locale locale;

  const AppSettingsState({required this.theme, required this.locale});

  AppSettingsState copyWith({ThemeMode? theme, Locale? locale}) {
    return AppSettingsState(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
    );
  }
}
