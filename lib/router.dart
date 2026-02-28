import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/BreathSessionConstructorService.dart';
import 'package:mind/BreathModule/BreathSessionListCoordinator.dart';
import 'package:mind/BreathModule/BreathSessionListService.dart';
import 'package:mind/BreathModule/BreathSessionService.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/BreathModule/ClockTickService.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeScreen.dart';
import 'package:mind/ProfileModule/ProfileCoordinator.dart';
import 'package:mind/ProfileModule/ProfileService.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/LoginService.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/Views/ComingSoonScreen.dart';

final appRouter = GoRouter(
  onEnter: (context, currentState, nextState, router) {
    final hasHost = nextState.uri.host.isNotEmpty;
    final hasScheme = nextState.uri.scheme.isNotEmpty;
    if (hasHost || hasScheme) {
      return const Block.stop();
    }
    return const Allow();
  },
  routes: [
    GoRoute(
      path: HomeScreen.path,
      name: HomeScreen.name,
      builder: (context, state) {
        return HomeScreen(coordinator: HomeCoordinator(context));
      },
    ),
    GoRoute(
      path: BreathSessionListScreen.path,
      name: BreathSessionListScreen.name,
      builder: (context, state) {
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
      },
    ),
    GoRoute(
      path: ComingSoonScreen.path,
      name: ComingSoonScreen.name,
      builder: (_, _) => const ComingSoonScreen(),
    ),
    GoRoute(
      path: OnboardingScreen.path,
      name: OnboardingScreen.name,
      builder: (context, state) {
        final returnPath = state.extra as String? ?? '/';
        final service = LoginService(userNotifier: App.shared.userNotifier);
        return ProviderScope(
          overrides: [
            loginViewModelProvider.overrideWith(
              (ref) => LoginViewModel(service: service, returnPath: returnPath),
            ),
          ],
          child: const OnboardingScreen(),
        );
      },
    ),
    GoRoute(
      path: LoginScreen.path,
      name: LoginScreen.name,
      builder: (context, state) {
        final returnPath = state.extra as String? ?? '/';
        final service = LoginService(userNotifier: App.shared.userNotifier);
        return ProviderScope(
          overrides: [
            loginViewModelProvider.overrideWith(
              (ref) => LoginViewModel(service: service, returnPath: returnPath),
            ),
          ],
          child: const LoginScreen(),
        );
      },
    ),
    GoRoute(
      path: BreathSessionScreen.path,
      name: BreathSessionScreen.name,
      builder: (context, state) {
        ClockTickService tickService = ClockTickService();
        tickService.simulateTick();
        final notifier = App.shared.breathSessionNotifier;
        final service = BreathSessionService(notifier: notifier);

        final sessionId = state.extra as String;

        return ProviderScope(
          overrides: [
            breathViewModelProvider.overrideWith(
              (ref) => BreathViewModel(
                tickService: tickService,
                service: service,
                sessionId: sessionId,
              ),
            ),
          ],
          child: const BreathSessionScreen(),
        );
      },
    ),
    GoRoute(
      path: BreathSessionConstructorScreen.path,
      name: BreathSessionConstructorScreen.name,
      builder: (context, state) {
        final app = App.shared;
        final userId = app.userNotifier.currentState.user.id;
        final session = state.extra is BreathSession ? state.extra as BreathSession : BreathSession.defaultSession();

        final service = BreathSessionConstructorService(userId: userId, existingSession: session, provider: app.breathSessionNotifier);

        return ProviderScope(
          overrides: [
            breathSessionConstructorProvider.overrideWith(
              (ref) => BreathSessionConstructorViewModel(service: service),
            ),
          ],
          child: const BreathSessionConstructorScreen(),
        );
      },
    ),
    GoRoute(
      path: ProfileScreen.path,
      name: ProfileScreen.name,
      builder: (context, state) {
        final app = App.shared;
        final appVersion = state.extra as String? ?? '';
        final service = ProfileService(userNotifier: app.userNotifier, appVersion: appVersion);
        final coordinator = ProfileCoordinator(context);
        return ProviderScope(
          overrides: [
            profileViewModelProvider.overrideWith(
              (ref) => ProfileViewModel(service: service, coordinator: coordinator),
            ),
          ],
          child: const ProfileScreen(),
        );
      },
    ),
  ],
);
