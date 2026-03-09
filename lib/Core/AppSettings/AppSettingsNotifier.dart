import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsState.dart';

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>(
      (ref) => throw UnimplementedError(
        'AppSettingsNotifier must be overridden at ProviderScope',
      ),
    );

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final AppSettingsRepository _repository;

  AppSettingsNotifier({
    required AppSettingsRepository repository,
    required AppSettingsState initialState,
  })  : _repository = repository,
        super(initialState);

  AppSettingsState get currentState => state;

  Future<void> setTheme(ThemeMode mode) async {
    await _repository.setTheme(mode);
    state = state.copyWith(theme: mode);
  }

  Future<void> setLanguage(String languageCode) async {
    await _repository.setLanguage(languageCode);
    state = state.copyWith(locale: Locale(languageCode));
  }
}
