import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart';

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(
      () => throw UnimplementedError(
        'ProfileViewModel must be overridden at ProviderScope',
      ),
    );

class ProfileViewModel extends Notifier<ProfileState> {
  final IProfileService service;
  final IProfileCoordinator coordinator;

  ProfileViewModel({required this.service, required this.coordinator});

  @override
  ProfileState build() {
    final subscription = service.observeProfile().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());

    service.appVersion.then((version) {
      state = state.copyWith(appVersion: version);
    });

    return ProfileState(
      theme: service.currentTheme,
      language: service.currentLanguage,
      isAuthenticated: service.isAuthenticated,
    );
  }

  void _onEvent(ProfileEvent event) {
    switch (event) {
      case ProfileLoaded e:
        state = state.copyWith(isAuthenticated: true, userName: e.user.name);
      case ProfileGuest _:
        state = state.copyWith(isAuthenticated: false);
    }
  }

  void onLoginTap() {
    coordinator.login();
  }

  void onLogoutTap() {
    coordinator.logout();
  }

  void onMcpTap() {
    coordinator.openMcp();
  }

  Future<void> onNameChanged(String name) async {
    await service.updateName(name);
  }

  void onThemeTap() {
    final keys = service.themeOptions;
    final currentIndex = keys.indexOf(state.theme).clamp(0, keys.length - 1);
    coordinator.showThemePicker(
      keys: keys,
      selectedIndex: currentIndex,
      onSelect: (index) => onThemeChanged(keys[index]),
    );
  }

  void onLanguageTap() {
    final keys = service.languageOptions;
    final currentIndex = keys.indexOf(state.language).clamp(0, keys.length - 1);
    coordinator.showLanguagePicker(
      keys: keys,
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
}
