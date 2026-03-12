import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsState.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:rxdart/rxdart.dart';

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>(
      (ref) => throw UnimplementedError(
        'AppSettingsNotifier must be overridden at ProviderScope',
      ),
    );

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final AppSettingsRepository _repository;
  StreamSubscription<AuthenticatedState>? _authSubscription;

  AppSettingsNotifier({
    required AppSettingsRepository repository,
    required AppSettingsState initialState,
    Stream<AuthState>? authStateStream,
  })  : _repository = repository,
        super(initialState) {
    if (authStateStream != null) {
      _authSubscription = authStateStream
          .whereType<AuthenticatedState>()
          .listen((state) {
        final lang = state.user.language;
        if (lang.isNotEmpty) setLanguage(lang);
      });
    }
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
