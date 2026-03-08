import 'package:flutter/widgets.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeScreen.dart';

class HomeModule {
  static Widget buildHomeScreen(BuildContext context) {
    return HomeScreen(coordinator: HomeCoordinator(context));
  }
}
