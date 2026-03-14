// STYLE RULE: All initializers in initialize() must be written as single-line statements.
// Multi-line named-parameter calls are NOT allowed here. Keep each assignment on one line.
// No trailing commas on initializer lines — parameters are added in the middle, not the end.
// Example: final foo = Foo(a: a, b: b, c: c);
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mind/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/Core/Api/AuthApi.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/BreathSessionApi.dart';
import 'package:mind/Core/Api/DeviceApi.dart';
import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/UserApi.dart';
import 'package:mind/Device/DeviceRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsState.dart';
import 'package:mind/Core/AppSettings/SharedPreferencesStorage.dart';
import 'package:mind/Core/AppTheme.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/Core/DeeplinkRouter.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';
import 'package:mind/Core/Handlers/BreathSessionDeeplinkHandler.dart';
import 'package:mind/User/Infrastructure/GoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/SecureStorage.dart';
import 'package:mind/BreathModule/Core/LiveSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveSessionService.dart';
import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/Core/Socket/PresenceNotifier.dart';
import 'package:mind/Core/Socket/SocketConnectionCoordinator.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';
import 'package:mind/Core/GlobalUI/GlobalListeners.dart';
import 'package:mind/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final AppSettingsNotifier appSettingsNotifier;
  final LiveSocketService liveSocketService;
  final SocketConnectionCoordinator socketConnectionCoordinator;
  final PresenceNotifier presenceNotifier;
  final LiveSessionNotifier liveSessionNotifier;
  final LiveSessionService liveSessionService;

  App._({
    required this.db,
    required this.httpClient,
    required this.logoutNotifier,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
    required this.appSettingsNotifier,
    required this.liveSocketService,
    required this.socketConnectionCoordinator,
    required this.presenceNotifier,
    required this.liveSessionNotifier,
    required this.liveSessionService,
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
    final userApi = UserApi(httpClient);
    final breathSessionApi = BreathSessionApi(httpClient);

    final deviceApi = DeviceApi(httpClient);
    unawaited(DeviceRepository(api: deviceApi, storage: SecureStorage()).ping());

    final userRepository = UserRepository(userDao: db.userDao, api: authApi, userApi: userApi, google: GoogleAuthProvider(), storage: SecureStorage());
    final breathSessionRepository = BreathSessionRepository(dao: db.breathSessionDao, api: breathSessionApi);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository, userNotifier: userNotifier);

    final prefs = await SharedPreferences.getInstance();
    final appSettingsRepository = AppSettingsRepository(SharedPreferencesStorage(prefs));
    await appSettingsRepository.init();
    final initialTheme = await appSettingsRepository.getTheme();
    final initialLanguage = await appSettingsRepository.getLanguage();
    // authStateStream: server language wins on login — AppSettingsNotifier
    // listens for AuthenticatedState and overwrites the local language with
    // the value returned by the server. This ensures the language set during
    // registration propagates back to the device on first sign-in.
    final appSettingsNotifier = AppSettingsNotifier(
      repository: appSettingsRepository,
      initialState: AppSettingsState(theme: initialTheme, language: initialLanguage),
      authStateStream: userNotifier.stream,
    );

    final authCodeHandler = AuthCodeDeeplinkHandler(userNotifier: userNotifier);
    final sessionHandler = BreathSessionDeeplinkHandler(router: appRouter);
    final deeplinkRouter = DeeplinkRouter(authCodeHandler: authCodeHandler, sessionHandler: sessionHandler);

    final liveSocketService = LiveSocketService(storage: const FlutterSecureStorage());

    final socketConnectionCoordinator = SocketConnectionCoordinator(userNotifier: userNotifier, liveSocketService: liveSocketService);
    final presenceNotifier = PresenceNotifier(liveSocketService: liveSocketService);
    final liveSessionNotifier = LiveSessionNotifier(liveSocketService: liveSocketService, userNotifier: userNotifier);
    final liveSessionService = LiveSessionService(notifier: liveSessionNotifier);

    shared = App._(
      db: db,
      httpClient: httpClient,
      logoutNotifier: logoutNotifier,
      userRepository: userRepository,
      breathSessionRepository: breathSessionRepository,
      userNotifier: userNotifier,
      breathSessionNotifier: breathSessionNotifier,
      deeplinkRouter: deeplinkRouter,
      appSettingsNotifier: appSettingsNotifier,
      liveSocketService: liveSocketService,
      socketConnectionCoordinator: socketConnectionCoordinator,
      presenceNotifier: presenceNotifier,
      liveSessionNotifier: liveSessionNotifier,
      liveSessionService: liveSessionService,
    );

    await shared.deeplinkRouter.init();

    runApp(ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith((ref) => appSettingsNotifier),
      ],
      child: const MyApp(),
    ));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static ThemeMode _themeModeFromKey(String key) {
    switch (key) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default: return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Mind',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeModeFromKey(settings.theme),
      locale: Locale(settings.language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
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
