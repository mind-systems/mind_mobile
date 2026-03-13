import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/BreathSessionConstructorCoordinator.dart';
import 'package:mind/BreathModule/BreathSessionConstructorService.dart';
import 'package:mind/BreathModule/BreathSessionListCoordinator.dart';
import 'package:mind/BreathModule/BreathSessionCoordinator.dart';
import 'package:mind/BreathModule/BreathSessionListService.dart';
import 'package:mind/BreathModule/BreathSessionService.dart';
import 'package:mind/BreathModule/ClockTickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';
import 'package:mind/Core/App.dart';

class BreathModule {
  static Widget buildSessionList(BuildContext context) {
    final app = App.shared;
    final service = BreathSessionListService(notifier: app.breathSessionNotifier, userNotifier: app.userNotifier);
    final coordinator = BreathSessionListCoordinator(context);
    return ProviderScope(
      overrides: [
        breathSessionListViewModelProvider.overrideWith(
          (ref) => BreathSessionListViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const BreathSessionListScreen(),
    );
  }

  static Widget buildSession(BuildContext context, {required String sessionId}) {
    final tickService = ClockTickService()..simulateTick();
    final service = BreathSessionService(notifier: App.shared.breathSessionNotifier, userNotifier: App.shared.userNotifier);
    final coordinator = BreathSessionCoordinator(context, userNotifier: App.shared.userNotifier);
    return ProviderScope(
      overrides: [
        breathViewModelProvider.overrideWith(
          (ref) => BreathViewModel(tickService: tickService, service: service, coordinator: coordinator, sessionId: sessionId),
        ),
      ],
      child: const BreathSessionScreen(),
    );
  }

  static Widget buildConstructor(BuildContext context, {String? sessionId}) {
    final app = App.shared;
    final userId = app.userNotifier.currentState.user.id;
    final session = sessionId != null
        ? app.breathSessionNotifier.currentState.byId[sessionId]
        : null;
    assert(sessionId == null || session != null, 'Session $sessionId not found in cache — was it deleted before navigation?');
    final service = BreathSessionConstructorService(userId: userId, existingSession: session, provider: app.breathSessionNotifier, userNotifier: app.userNotifier);
    final coordinator = BreathSessionConstructorCoordinator(context);
    return ProviderScope(
      overrides: [
        breathSessionConstructorProvider.overrideWith(
          (ref) => BreathSessionConstructorViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const BreathSessionConstructorScreen(),
    );
  }
}
