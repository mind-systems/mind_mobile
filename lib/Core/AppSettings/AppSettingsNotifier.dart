import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsState.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:rxdart/rxdart.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
      () => throw UnimplementedError(
        'AppSettingsNotifier must be overridden at ProviderScope',
      ),
    );

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  final AppSettingsRepository _repository;
  final AppSettingsState _initialState;
  final Stream<AuthState>? _authStateStream;

  AppSettingsNotifier({
    required AppSettingsRepository repository,
    required AppSettingsState initialState,
    Stream<AuthState>? authStateStream,
  })  : _repository = repository,
        _initialState = initialState,
        _authStateStream = authStateStream;

  @override
  AppSettingsState build() {
    if (_authStateStream != null) {
      final subscription = _authStateStream
          .whereType<AuthenticatedState>()
          .listen((authState) {
        final lang = authState.user.language;
        if (lang.isNotEmpty) setLanguage(lang);
      });
      ref.onDispose(() => subscription.cancel());
    }
    return _initialState;
  }

  AppSettingsState get currentState => state;

  Future<void> setTheme(String key) async {
    await _repository.setTheme(key);
    state = state.copyWith(theme: key);
  }

  Future<void> setLanguage(String languageCode) async {
    await _repository.setLanguage(languageCode);
    state = state.copyWith(language: languageCode);
  }
}
