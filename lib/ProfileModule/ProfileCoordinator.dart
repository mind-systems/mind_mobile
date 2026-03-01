import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';

class ProfileCoordinator implements IProfileCoordinator {
  final BuildContext context;

  ProfileCoordinator(this.context);

  @override
  void logout() {
    App.shared.userNotifier.logout().then((_) {
      if (context.mounted) {
        context.pop();
      }
    });
  }
}
