import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/BreathSessionConstructorService.dart';
import 'package:mind/BreathModule/BreathSessionListService.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';
import 'package:mind/BreathSessionMocks.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/HomePage.dart';
import 'package:mind/BreathModule/ClockTickService.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/User/UserNotifier.dart';

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
    GoRoute(path: '/', name: 'home', builder: (_, _) => const HomePage()),
    GoRoute(
      path: OnboardingScreen.path,
      name: OnboardingScreen.name,
      builder: (context, state) {
        final returnPath = state.extra as String? ?? '/';
        return ProviderScope(
          overrides: [
            loginViewModelProvider.overrideWith(
              (ref) => LoginViewModel(ref: ref, returnPath: returnPath),
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
        return ProviderScope(
          overrides: [
            loginViewModelProvider.overrideWith(
              (ref) => LoginViewModel(ref: ref, returnPath: returnPath),
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
        // Выбери нужную тестовую сессию:
        // final session = BreathSessionMocks.quickTestSession;       // Быстрая
        // final session = BreathSessionMocks.triangleOnlySession;    // Только треугольники
        final session = BreathSessionMocks.boxOnlySession;         // Только квадраты
        // final session = BreathSessionMocks.mixedShapesSession;     // Микс форм
        // final session = BreathSessionMocks.fullTestSession;        // Полная тестовая
        // final session = BreathSessionMocks.longSession;            // Длинная сессия

        return ProviderScope(
          overrides: [
            breathViewModelProvider.overrideWith(
              (ref) => BreathViewModel(
                tickService: tickService,
                session: session,
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
        final container = ProviderScope.containerOf(context);
        final userId = container.read(userNotifierProvider).user.id;
        final session = state.extra is BreathSession ? state.extra as BreathSession : BreathSession.defaultSession();
        final provider = container.read(breathSessionNotifierProvider.notifier);

        final service = BreathSessionConstructorService(userId: userId, existingSession: session, provider: provider);

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
      path: BreathSessionListScreen.path,
      name: BreathSessionListScreen.name,
      builder: (context, state) {
        final container = ProviderScope.containerOf(context);
        final breathSessionNotifier = container.read(breathSessionNotifierProvider.notifier);
        final userNotifier = container.read(userNotifierProvider.notifier);

        final service = BreathSessionListService(notifier: breathSessionNotifier, userNotifier: userNotifier);

        return ProviderScope(
          overrides: [
            breathSessionListViewModelProvider.overrideWith(
              (ref) => BreathSessionListViewModel(service: service),
            ),
          ],
          child: const BreathSessionListScreen(),
        );
      },
    ),
  ],
);
