import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/BreathModule.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/HomeModule/HomeModule.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeScreen.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'package:mind/ProfileModule/ProfileModule.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/User/Presentation/Login/OnboardingModule.dart';
import 'package:mind_ui/mind_ui.dart';

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
      builder: (context, state) => HomeModule.buildHomeScreen(context),
    ),
    GoRoute(
      path: BreathSessionListScreen.path,
      name: BreathSessionListScreen.name,
      builder: (context, state) => BreathModule.buildSessionList(context),
    ),
    GoRoute(
      path: BreathSessionScreen.path,
      name: BreathSessionScreen.name,
      builder: (context, state) {
        final sessionId = state.extra as String;
        return BreathModule.buildSession(context, sessionId: sessionId);
      },
    ),
    GoRoute(
      path: BreathSessionConstructorScreen.path,
      name: BreathSessionConstructorScreen.name,
      builder: (context, state) {
        final sessionId = state.extra as String?;
        return BreathModule.buildConstructor(context, sessionId: sessionId);
      },
    ),
    GoRoute(
      path: OnboardingScreen.path,
      name: OnboardingScreen.name,
      builder: (context, state) => OnboardingModule.buildOnboarding(context),
    ),
    GoRoute(
      path: LoginScreen.path,
      name: LoginScreen.name,
      builder: (context, state) => OnboardingModule.buildLogin(context),
    ),
    GoRoute(
      path: ProfileScreen.path,
      name: ProfileScreen.name,
      builder: (context, state) {
        return ProfileModule.buildProfileScreen(context);
      },
    ),
    GoRoute(
      path: ComingSoonScreen.path,
      name: ComingSoonScreen.name,
      builder: (_, _) => const ComingSoonScreen(),
    ),
  ],
);
