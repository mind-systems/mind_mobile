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
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';

class AppInitializer {
  static Future<void> initialize({required FirebaseOptions firebaseOptions,}) async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(options: firebaseOptions);
    await GoogleSignIn.instance.initialize();

    final db = Database();
    final logoutNotifier = LogoutNotifier();
    final authInterceptor = AuthInterceptor(storage: const FlutterSecureStorage(), logoutNotifier: logoutNotifier);
    final api = ApiService(authInterceptor: authInterceptor);

    final userRepository = UserRepository(db: db, api: api);
    final initialUser = await userRepository.loadUser();

    final firebaseHandler = FirebaseDeeplinkHandler(userRepository: userRepository);
    final deeplinkRouter = DeeplinkRouter(firebaseHandler: firebaseHandler);
    await deeplinkRouter.init();

    final breathSessionRepository = BreathSessionRepository(db: db, api: api);

    runApp(
      ProviderScope(
        overrides: [
          logoutNotifierProvider.overrideWith(() => logoutNotifier),
          userNotifierProvider.overrideWith(
            () => UserNotifier(
              repository: userRepository,
              initialUser: initialUser,
            ),
          ),
          breathSessionNotifierProvider.overrideWith(
            () => BreathSessionNotifier(repository: breathSessionRepository),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(context) {
    return MaterialApp.router(
      title: 'Mind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: appRouter,
    );
  }
}
