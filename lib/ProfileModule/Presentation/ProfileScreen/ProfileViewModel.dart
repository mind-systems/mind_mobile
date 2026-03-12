import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart';

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>(
      (ref) => throw UnimplementedError(
        'ProfileViewModel must be overridden at ProviderScope',
      ),
    );

class ProfileViewModel extends StateNotifier<ProfileState> {
  final IProfileService service;
  final IProfileCoordinator coordinator;

  StreamSubscription<ProfileEvent>? _subscription;

  ProfileViewModel({required this.service, required this.coordinator})
      : super(ProfileState(
          theme: service.currentTheme,
          language: service.currentLanguage,
        )) {
    _subscription = service.observeProfile().listen(_onEvent);
    service.appVersion.then((version) {
      state = state.copyWith(appVersion: version);
    });
  }

  void _onEvent(ProfileEvent event) {
    switch (event) {
      case ProfileLoaded e:
        state = state.copyWith(userName: e.user.name);
    }
  }

  void onLogoutTap() {
    coordinator.logout();
  }

  Future<void> onNameChanged(String name) async {
    await service.updateName(name);
  }

  void onThemeTap() {
    final keys = service.themeOptions;
    final currentIndex = keys.indexOf(state.theme).clamp(0, keys.length - 1);
    coordinator.showPicker(
      title: 'Theme',
      options: keys.map(_displayTheme).toList(),
      selectedIndex: currentIndex,
      onSelect: (index) => onThemeChanged(keys[index]),
    );
  }

  void onLanguageTap() {
    final keys = service.languageOptions;
    final currentIndex = keys.indexOf(state.language).clamp(0, keys.length - 1);
    coordinator.showPicker(
      title: 'Language',
      options: keys.map(_displayLanguage).toList(),
      selectedIndex: currentIndex,
      onSelect: (index) => onLanguageChanged(keys[index]),
    );
  }

  Future<void> onThemeChanged(String key) async {
    await service.updateTheme(key);
    state = state.copyWith(theme: key);
  }

  Future<void> onLanguageChanged(String key) async {
    await service.updateLanguage(key);
    state = state.copyWith(language: key);
  }

  // Display helpers — temporary until localization; replaced by l10n.themeLabel(key)
  static String _displayTheme(String key) {
    switch (key) {
      case 'dark': return 'Dark';
      case 'light': return 'Light';
      default: return 'System';
    }
  }

  static String _displayLanguage(String key) {
    switch (key) {
      case 'ru': return 'Русский';
      default: return 'English';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
