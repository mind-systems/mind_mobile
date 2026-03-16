import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart';
import 'package:mind_ui/mind_ui.dart';
import 'package:mind_l10n/mind_l10n.dart';

class ProfileScreen extends ConsumerWidget {
  static const String path = '/profile';
  static const String name = 'profile';

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final themeDisplay = switch (state.theme) {
      'dark' => l10n.themeDark,
      'light' => l10n.themeLight,
      _ => l10n.themeSystem,
    };
    final languageDisplay = switch (state.language) {
      'ru' => 'Русский',
      _ => 'English',
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SettingsSectionHeader(title: l10n.account),
            SettingsSection(
              children: [
                SettingsEditableCell(
                  title: l10n.name,
                  value: state.userName,
                  onSave: viewModel.onNameChanged,
                ),
              ],
            ),
            SettingsSectionHeader(title: l10n.appearance),
            SettingsSection(
              children: [
                SettingsDropdownCell(
                  title: l10n.language,
                  value: languageDisplay,
                  onTap: viewModel.onLanguageTap,
                ),
                SettingsDropdownCell(
                  title: l10n.theme,
                  value: themeDisplay,
                  onTap: viewModel.onThemeTap,
                ),
              ],
            ),
            SettingsSectionHeader(title: l10n.session),
            SettingsSection(
              children: [
                SettingsCell(
                  title: Text(l10n.logOut),
                  onTap: () async {
                    final result = await AppAlert.showWithInput(
                      context,
                      description: l10n.logOutDescription,
                      confirmLabel: l10n.logOut,
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
