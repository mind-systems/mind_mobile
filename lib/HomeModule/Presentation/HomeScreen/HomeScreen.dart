import 'package:flutter/material.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/IHomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/ModuleItem.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/HomeScreenCell.dart';
import 'package:mind_l10n/mind_l10n.dart';

class HomeScreen extends StatelessWidget {
  static const String path = '/';
  static const String name = 'home';

  final IHomeCoordinator coordinator;

  const HomeScreen({super.key, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = [
      ModuleItem(
        title: l10n.homeTabBreath,
        iconPath: 'assets/images/modules/home/breath.png',
        onTap: coordinator.openBreath,
      ),
      ModuleItem(
        title: l10n.homeTabMind,
        iconPath: 'assets/images/modules/home/bci.png',
        onTap: coordinator.openComingSoon,
      ),
      ModuleItem(
        title: l10n.profile,
        iconPath: 'assets/images/modules/home/profile.png',
        onTap: coordinator.openProfile,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: CustomScrollView(
        slivers: [
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
          const SliverToBoxAdapter(child: SuggestionsCard()),
          // todo debug
          const SliverToBoxAdapter(child: StatsCard()),
        ],
      )),
    );
  }
}
