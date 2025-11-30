import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/HomePage.dart';

import 'User/Presentation/Login/OnboardingScreen.dart';

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
      path: '/',
      name: 'home',
      builder: (_, _) => const HomePage()
    ),
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
      }
    ),
  ]
);
