import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart';
import 'package:mind/Views/AlertModule/AppAlert.dart';
import 'package:mind/Views/SettingsCells/SettingsCell.dart';
import 'package:mind/Views/SettingsCells/SettingsEditableCell.dart';
import 'package:mind/Views/SettingsCells/SettingsDropdownCell.dart';
import 'package:mind/Views/SettingsCells/SettingsSection.dart';
import 'package:mind/Views/SettingsCells/SettingsSectionHeader.dart';

class ProfileScreen extends ConsumerWidget {
  static const String path = '/profile';
  static const String name = 'profile';

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SettingsSectionHeader(title: 'Account'),
            SettingsSection(
              children: [
                SettingsEditableCell(
                  title: 'Name',
                  value: state.userName,
                  onSave: viewModel.onNameChanged,
                ),
              ],
            ),
            const SettingsSectionHeader(title: 'Appearance'),
            SettingsSection(
              children: [
                SettingsDropdownCell(
                  title: 'Language',
                  value: state.languageLabel,
                  onTap: viewModel.onLanguageTap,
                ),
                SettingsDropdownCell(
                  title: 'Theme',
                  value: state.themeLabel,
                  onTap: viewModel.onThemeTap,
                ),
              ],
            ),
            const SettingsSectionHeader(title: 'Session'),
            SettingsSection(
              children: [
                SettingsCell(
                  title: const Text('Log out'),
                  onTap: () async {
                    final result = await AppAlert.showWithInput(
                      context,
                      description: 'Come back again soon',
                      confirmLabel: 'Log out',
                      cancelLabel: 'Cancel',
                    );
                    if (result.confirmed) viewModel.onLogoutTap();
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'v ${state.appVersion ?? '...'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
