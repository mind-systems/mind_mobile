import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';
import 'package:mind/Views/OptionPickerSheet.dart';

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

  @override
  void showPicker({
    required String title,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    showOptionPickerSheet(
      context,
      title: title,
      options: options,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
  }
}
