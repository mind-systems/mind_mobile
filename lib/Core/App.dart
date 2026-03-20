// STYLE RULE: All initializers in initialize() must be written as single-line statements.
// Multi-line named-parameter calls are NOT allowed here. Keep each assignment on one line.
// No trailing commas on initializer lines — parameters are added in the middle, not the end.
// Example: final foo = Foo(a: a, b: b, c: c);
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mind_l10n/mind_l10n.dart';
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
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Api/SyncApi.dart';
import 'package:mind/Core/Api/TokenApi.dart';
import 'package:mind/Core/Api/ITokenApi.dart';
import 'package:mind/Core/Api/UserApi.dart';
import 'package:mind/Core/Socket/SocketDebugOverlay.dart';
import 'package:mind/User/IUserApi.dart';
import 'package:mind/Device/DeviceRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
import 'package:mind/Core/AppSettings/AppSettingsRepository.dart';
import 'package:mind/Core/AppSettings/AppSettingsState.dart';
import 'package:mind/Core/AppSettings/SharedPreferencesStorage.dart';
import 'package:mind_ui/mind_ui.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/Core/DeeplinkRouter.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';
import 'package:mind/Core/Handlers/BreathSessionDeeplinkHandler.dart';
import 'package:mind/User/Infrastructure/GoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/SecureStorage.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionService.dart';
import 'package:mind/BreathModule/Core/BreathTelemetryService.dart';
import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/Core/Socket/SocketConnectionCoordinator.dart';
import 'package:mind/Core/Sync/SyncEngine.dart';
import 'package:mind/Core/Sync/SyncSocketListener.dart';
import 'package:mind/McpModule/Core/TokenNotifier.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';
import 'package:mind/Core/GlobalUI/GlobalListeners.dart';
import 'package:mind/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App {
  static late App shared;

  final Database db;
  final HttpClient httpClient;
  // todo debug for stats
  final IUserApi userApi;
  final ITokenApi tokenApi;
  final ISyncApi syncApi;
  final UserRepository userRepository;
  final BreathSessionRepository breathSessionRepository;
  final UserNotifier userNotifier;
  final BreathSessionNotifier breathSessionNotifier;
  final DeeplinkRouter deeplinkRouter;
  final AppSettingsNotifier appSettingsNotifier;
  final LiveSocketService liveSocketService;
  final SocketConnectionCoordinator socketConnectionCoordinator;
  final LiveBreathSessionNotifier liveSessionNotifier;
  final LiveBreathSessionService liveSessionService;
  final BreathTelemetryService telemetryService;
  final TokenNotifier tokenNotifier;
  final SyncEngine syncEngine;
  final SyncSocketListener syncSocketListener;

  App._({
    required this.db,
    required this.httpClient,
    required this.userApi,
    required this.tokenApi,
    required this.syncApi,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
    required this.appSettingsNotifier,
    required this.liveSocketService,
    required this.socketConnectionCoordinator,
    required this.liveSessionNotifier,
    required this.liveSessionService,
    required this.telemetryService,
    required this.tokenNotifier,
    required this.syncEngine,
    required this.syncSocketListener,
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
    final tokenApi = TokenApi(httpClient);
    final breathSessionApi = BreathSessionApi(httpClient);
    final syncApi = SyncApi(httpClient);

    final deviceApi = DeviceApi(httpClient);
    unawaited(DeviceRepository(api: deviceApi, storage: SecureStorage()).ping());

    final userRepository = UserRepository(userDao: db.userDao, api: authApi, userApi: userApi, google: GoogleAuthProvider(), storage: SecureStorage());
    final breathSessionRepository = BreathSessionRepository(dao: db.breathSessionDao, api: breathSessionApi);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository, authStream: userNotifier.stream);
    final syncEngine = SyncEngine(syncApi: syncApi, syncStateDao: db.syncStateDao, breathSessionDao: db.breathSessionDao, breathSessionNotifier: breathSessionNotifier);
    if (!initialUser.isGuest) {
      await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    userNotifier.stream
        .skip(1)
        .where((s) => s is AuthenticatedState)
        .listen((_) => syncEngine.sync());

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
    final syncSocketListener = SyncSocketListener(liveSocketService: liveSocketService, syncEngine: syncEngine);

    final socketConnectionCoordinator = SocketConnectionCoordinator(userNotifier: userNotifier, liveSocketService: liveSocketService);
    final liveSessionNotifier = LiveBreathSessionNotifier(liveSocketService: liveSocketService, authStream: userNotifier.stream);
    final liveSessionService = LiveBreathSessionService(notifier: liveSessionNotifier);
    final telemetryService = BreathTelemetryService(liveSocketService: liveSocketService);
    final tokenNotifier = TokenNotifier(api: tokenApi);

    shared = App._(
      db: db,
      httpClient: httpClient,
      userApi: userApi,
      tokenApi: tokenApi,
      syncApi: syncApi,
      userRepository: userRepository,
      breathSessionRepository: breathSessionRepository,
      userNotifier: userNotifier,
      breathSessionNotifier: breathSessionNotifier,
      deeplinkRouter: deeplinkRouter,
      appSettingsNotifier: appSettingsNotifier,
      liveSocketService: liveSocketService,
      socketConnectionCoordinator: socketConnectionCoordinator,
      liveSessionNotifier: liveSessionNotifier,
      liveSessionService: liveSessionService,
      telemetryService: telemetryService,
      tokenNotifier: tokenNotifier,
      syncEngine: syncEngine,
      syncSocketListener: syncSocketListener,
    );

    await shared.deeplinkRouter.init();

    runApp(ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => appSettingsNotifier),
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppSettingsRepository.supportedLocales
          .map((code) => Locale(code))
          .toList(),
      routerConfig: appRouter,
      builder: (context, child) {
        final body = GlobalListeners(
          sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream,
          authErrorStream: App.shared.userNotifier.authErrorStream,
          child: child!,
        );
        if (Environment.instance.isProduction) return body;
        return Stack(children: [body, const SocketDebugOverlay()]);
      },
    );
  }
}
