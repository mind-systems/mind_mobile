import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/router.dart';

import 'package:mind/Core/Api/ApiService.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/Core/DeeplinkRouter.dart';
import 'package:mind/Core/Handlers/FirebaseDeeplinkHandler.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';
import 'package:mind/Core/GlobalUI/GlobalListeners.dart';

class App {
  static late App shared;

  final Database db;
  final ApiService api;
  final LogoutNotifier logoutNotifier;
  final UserRepository userRepository;
  final BreathSessionRepository breathSessionRepository;
  final UserNotifier userNotifier;
  final BreathSessionNotifier breathSessionNotifier;
  final DeeplinkRouter deeplinkRouter;

  App._({
    required this.db,
    required this.api,
    required this.logoutNotifier,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
  });

  static Future<void> initialize({required FirebaseOptions firebaseOptions}) async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(options: firebaseOptions);
    await GoogleSignIn.instance.initialize();

    final db = Database();
    final logoutNotifier = LogoutNotifier();

    final authInterceptor = AuthInterceptor(storage: const FlutterSecureStorage(), logoutNotifier: logoutNotifier);
    final api = ApiService(authInterceptor: authInterceptor);

    final userRepository = UserRepository(db: db, api: api);
    final breathSessionRepository = BreathSessionRepository(db: db, api: api);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository);

    final firebaseHandler = FirebaseDeeplinkHandler(userRepository: userRepository);
    final deeplinkRouter = DeeplinkRouter(firebaseHandler: firebaseHandler);

    shared = App._(
      db: db,
      api: api,
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        return GlobalListeners(logoutNotifier: App.shared.logoutNotifier, child: child!);
      },
    );
  }
}
