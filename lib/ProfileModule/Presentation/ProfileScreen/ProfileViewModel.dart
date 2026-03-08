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
      : super(ProfileState.initial()) {
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
