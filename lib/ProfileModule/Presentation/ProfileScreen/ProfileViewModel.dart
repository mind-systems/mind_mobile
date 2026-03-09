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
          themeLabel: service.currentThemeLabel,
          languageLabel: service.currentLanguageLabel,
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

  void onNameChanged(String name) {
    // TODO: persist name change via service
  }

  void onThemeTap() {
    final options = service.themeOptions;
    final currentIndex = options.indexOf(state.themeLabel).clamp(0, options.length - 1);
    coordinator.showPicker(
      title: 'Theme',
      options: options,
      selectedIndex: currentIndex,
      onSelect: (index) => onThemeChanged(options[index]),
    );
  }

  void onLanguageTap() {
    final options = service.languageOptions;
    final currentIndex = options.indexOf(state.languageLabel).clamp(0, options.length - 1);
    coordinator.showPicker(
      title: 'Language',
      options: options,
      selectedIndex: currentIndex,
      onSelect: (index) => onLanguageChanged(options[index]),
    );
  }

  Future<void> onThemeChanged(String label) async {
    await service.updateTheme(label);
    state = state.copyWith(themeLabel: label);
  }

  Future<void> onLanguageChanged(String label) async {
    await service.updateLanguage(label);
    state = state.copyWith(languageLabel: label);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
