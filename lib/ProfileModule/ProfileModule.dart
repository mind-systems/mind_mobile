import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart';
import 'package:mind/ProfileModule/ProfileCoordinator.dart';
import 'package:mind/ProfileModule/ProfileService.dart';

class ProfileModule {
  static Widget buildProfileScreen(BuildContext context) {
    final service = ProfileService(userNotifier: App.shared.userNotifier);
    final coordinator = ProfileCoordinator(context);
    return ProviderScope(
      overrides: [
        profileViewModelProvider.overrideWith(
          (ref) => ProfileViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const ProfileScreen(),
    );
  }
}
