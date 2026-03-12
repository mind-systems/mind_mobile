import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart';
import 'package:mind/Views/OptionPickerSheet.dart';
import 'package:mind/l10n/app_localizations.dart';

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
  void showThemePicker({
    required List<String> keys,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final options = keys.map((key) => switch (key) {
      'dark' => l10n.themeDark,
      'light' => l10n.themeLight,
      _ => l10n.themeSystem,
    }).toList();
    showOptionPickerSheet(
      context,
      title: l10n.theme,
      options: options,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
  }

  @override
  void showLanguagePicker({
    required List<String> keys,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Language names always shown in their own language — not from ARB
    final options = keys.map((key) => switch (key) {
      'ru' => 'Русский',
      _ => 'English',
    }).toList();
    showOptionPickerSheet(
      context,
      title: l10n.language,
      options: options,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    );
  }
}
