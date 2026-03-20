import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/HomeModule/HomeService.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeScreen.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeViewModel.dart';

class HomeModule {
  static Widget buildHomeScreen(BuildContext context) {
    final service = HomeService(
      userApi: App.shared.userApi,
      liveSessionNotifier: App.shared.liveSessionNotifier,
      userNotifier: App.shared.userNotifier,
    );
    final coordinator = HomeCoordinator(context, userNotifier: App.shared.userNotifier);
    return ProviderScope(
      overrides: [
        homeViewModelProvider.overrideWith(
          () => HomeViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const HomeScreen(),
    );
  }
}
