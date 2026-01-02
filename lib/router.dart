import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathViewModel.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/HomePage.dart';

import 'BreathModule/ClockTickService.dart';
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
        BreathSession session = BreathSession(
          exercises: [
            ExerciseSet(
              steps: [],
              restDuration: 5,
              repeatCount: 0,
            ),
            ExerciseSet(
              steps: [
                ExerciseStep(type: StepType.inhale, duration: 4),
                ExerciseStep(type: StepType.exhale, duration: 4),
              ],
              restDuration: 5,
              repeatCount: 10,
            ),
            ExerciseSet(
              steps: [],
              restDuration: 5,
              repeatCount: 0,
            ),
            ExerciseSet(
              steps: [
                ExerciseStep(type: StepType.inhale, duration: 30),
                ExerciseStep(type: StepType.hold, duration: 30),
                ExerciseStep(type: StepType.exhale, duration: 60),
                ExerciseStep(type: StepType.hold, duration: 30),
              ],
              restDuration: 0,
              repeatCount: 3,
            ),
          ],
          tickSource: TickSource.heartbeat,
        );
        return ProviderScope(
          overrides: [
            breathViewModelProvider.overrideWith(
              (ref) =>
                  BreathViewModel(tickService: tickService, session: session),
            ),
          ],
          child: const BreathSessionScreen(),
        );
      },
    ),
  ],
);
