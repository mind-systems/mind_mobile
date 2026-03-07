import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/Core/Api/AuthApi.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/BreathSessionApi.dart';
import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/AppTheme.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/Core/DeeplinkRouter.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';
import 'package:mind/User/Infrastructure/GoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/SecureStorage.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';
import 'package:mind/Core/GlobalUI/GlobalListeners.dart';
import 'package:mind/router.dart';

class App {
  static late App shared;

  final Database db;
  final HttpClient httpClient;
  final LogoutNotifier logoutNotifier;
  final UserRepository userRepository;
  final BreathSessionRepository breathSessionRepository;
  final UserNotifier userNotifier;
  final BreathSessionNotifier breathSessionNotifier;
  final DeeplinkRouter deeplinkRouter;

  App._({
    required this.db,
    required this.httpClient,
    required this.logoutNotifier,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
  });

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS
          ? Environment.instance.googleIosClientId
          : Environment.instance.googleAndroidClientId,
      serverClientId: Environment.instance.googleServerClientId,
    );

    final db = Database();
    final logoutNotifier = LogoutNotifier();

    final authInterceptor = AuthInterceptor(storage: const FlutterSecureStorage(), logoutNotifier: logoutNotifier);
    final httpClient = HttpClient(authInterceptor: authInterceptor);
    final authApi = AuthApi(httpClient);
    final breathSessionApi = BreathSessionApi(httpClient);

    final userRepository = UserRepository(userDao: db.userDao, api: authApi, google: GoogleAuthProvider(), storage: SecureStorage());
    final breathSessionRepository = BreathSessionRepository(db: db, api: breathSessionApi);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository, userNotifier: userNotifier);

    final authCodeHandler = AuthCodeDeeplinkHandler(userNotifier: userNotifier);
    final deeplinkRouter = DeeplinkRouter(authCodeHandler: authCodeHandler);

    shared = App._(
      db: db,
      httpClient: httpClient,
      logoutNotifier: logoutNotifier,
      userRepository: userRepository,
      breathSessionRepository: breathSessionRepository,
      userNotifier: userNotifier,
      breathSessionNotifier: breathSessionNotifier,
      deeplinkRouter: deeplinkRouter,
    );

    await shared.deeplinkRouter.init();

    runApp(const ProviderScope(child: MyApp()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Mind',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return GlobalListeners(
          logoutNotifier: App.shared.logoutNotifier,
          authErrorStream: App.shared.userNotifier.authErrorStream,
          child: child!
        );
      },
    );
  }
}
