import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileService.dart';
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
      : super(ProfileState(appVersion: service.appVersion)) {
    _subscription = service.observeProfile().listen(_onEvent);
  }

  void _onEvent(ProfileEvent event) {
    switch (event) {
      case ProfileLoaded e:
        state = ProfileState(userName: e.user.name, appVersion: state.appVersion);
    }
  }

  void onLogoutTap() {
    coordinator.logout();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
