import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeViewModel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/ModuleItem.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/HomeScreenCell.dart';
import 'package:mind_l10n/mind_l10n.dart';

class HomeScreen extends ConsumerWidget {
  static const String path = '/';
  static const String name = 'home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(homeViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final modules = [
      ModuleItem(
        title: l10n.homeTabBreath,
        iconPath: 'assets/images/modules/home/breath.png',
        onTap: vm.onBreathTap,
      ),
      ModuleItem(
        title: l10n.homeTabMind,
        iconPath: 'assets/images/modules/home/bci.png',
        onTap: vm.onComingSoonTap,
      ),
      ModuleItem(
        title: l10n.profile,
        iconPath: 'assets/images/modules/home/profile.png',
        onTap: vm.onProfileTap,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SuggestionsCard()),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => HomeScreenCell(item: modules[index]),
                childCount: modules.length,
              ),
            ),
          ),
          // todo debug
          const SliverToBoxAdapter(child: StatsCard()),
        ],
      )),
    );
  }
}
