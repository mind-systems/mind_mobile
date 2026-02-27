import 'package:flutter/material.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/IHomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/ModuleItem.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/HomeScreenCell.dart';

class HomeScreen extends StatelessWidget {
  static const String path = '/';
  static const String name = 'home';

  final IHomeCoordinator coordinator;

  const HomeScreen({super.key, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    final modules = [
      ModuleItem(
        title: 'Breath',
        iconPath: 'assets/images/modules/home/breath.png',
        onTap: coordinator.openBreath,
      ),
      ModuleItem(
        title: 'Mind',
        iconPath: 'assets/images/modules/home/bci.png',
        onTap: coordinator.openComingSoon,
      ),
      ModuleItem(
        title: 'Profile',
        iconPath: 'assets/images/modules/home/profile.png',
        onTap: coordinator.openComingSoon,
      ),
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) => HomeScreenCell(item: modules[index]),
        ),
      ),
    );
  }
}
