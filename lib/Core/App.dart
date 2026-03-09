import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/Core/Api/AuthApi.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/BreathSessionApi.dart';
import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/SharedPreferencesStorage.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final localeProvider = StateProvider<Locale?>((ref) => null);

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
  final AppSettingsRepository appSettingsRepository;

  App._({
    required this.db,
    required this.httpClient,
    required this.logoutNotifier,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
    required this.appSettingsRepository,
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
    final breathSessionRepository = BreathSessionRepository(dao: db.breathSessionDao, api: breathSessionApi);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository, userNotifier: userNotifier);

    final authCodeHandler = AuthCodeDeeplinkHandler(userNotifier: userNotifier);
    final deeplinkRouter = DeeplinkRouter(authCodeHandler: authCodeHandler);

    final prefs = await SharedPreferences.getInstance();
    final appSettingsRepository = AppSettingsRepository(SharedPreferencesStorage(prefs));
    await appSettingsRepository.init();
    final initialTheme = await appSettingsRepository.getTheme();
    final initialLanguage = await appSettingsRepository.getLanguage();

    shared = App._(
      db: db,
      httpClient: httpClient,
      logoutNotifier: logoutNotifier,
      userRepository: userRepository,
      breathSessionRepository: breathSessionRepository,
      userNotifier: userNotifier,
      breathSessionNotifier: breathSessionNotifier,
      deeplinkRouter: deeplinkRouter,
      appSettingsRepository: appSettingsRepository,
    );

    await shared.deeplinkRouter.init();

    runApp(ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => initialTheme),
        localeProvider.overrideWith((ref) => Locale(initialLanguage)),
      ],
      child: const MyApp(),
    ));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Mind',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppSettingsRepository.supportedLocales
          .map((code) => Locale(code))
          .toList(),
      routerConfig: appRouter,
      builder: (context, child) {
        return GlobalListeners(
          logoutNotifier: App.shared.logoutNotifier,
          authErrorStream: App.shared.userNotifier.authErrorStream,
          child: child!,
        );
      },
    );
  }
}
