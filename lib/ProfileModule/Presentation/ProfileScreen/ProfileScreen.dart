import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart';
import 'package:mind/Views/AlertModule/AppAlert.dart';

class ProfileScreen extends ConsumerWidget {
  static const String path = '/profile';
  static const String name = 'profile';

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(state.userName ?? '—'),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Log out'),
            onTap: () async {
              final confirmed = await AppAlert.showConfirmation(
                context,
                title: 'Are you sure?',
                confirmLabel: 'Log out',
                cancelLabel: 'Cancel',
              );
              if (confirmed) viewModel.onLogoutTap();
            },
          ),
          const Spacer(),
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
    );
  }
}
