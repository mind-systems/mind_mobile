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
import 'package:mind/User/AuthApi.dart';
import 'package:mind/BreathModule/Core/BreathSessionApi.dart';
import 'package:mind/Device/DeviceApi.dart';
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Sync/SyncApi.dart';
import 'package:mind/McpModule/PersonalAccessTokenApi.dart';
import 'package:mind/Core/Api/IPersonalAccessTokenApi.dart';
import 'package:mind/User/IStatsApi.dart';
import 'package:mind/User/StatsApi.dart';
import 'package:mind/User/UserApi.dart';
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
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mind/Core/AppLifecycleService.dart';
import 'package:mind/Core/Grpc/GrpcAuthInterceptor.dart';
import 'package:mind/Core/Grpc/GrpcClient.dart';
import 'package:mind/Core/Grpc/LiveSessionGrpcService.dart';
import 'package:mind/Core/Sync/SyncEngine.dart';
import 'package:mind/Core/Sync/SyncGrpcListener.dart';
import 'package:mind/McpModule/Core/TokenNotifier.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';
import 'package:mind/Core/GlobalUI/GlobalListeners.dart';
import 'package:mind/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App {
  static late App shared;

  final Database db;
  final GrpcClient grpcClient;
  final IUserApi userApi;
  final IStatsApi statsApi;
  final IPersonalAccessTokenApi tokenApi;
  final ISyncApi syncApi;
  final UserRepository userRepository;
  final BreathSessionRepository breathSessionRepository;
  final UserNotifier userNotifier;
  final BreathSessionNotifier breathSessionNotifier;
  final DeeplinkRouter deeplinkRouter;
  final AppSettingsNotifier appSettingsNotifier;
  final LiveSessionGrpcService liveGrpcService;
  final LiveBreathSessionNotifier liveSessionNotifier;
  final LiveBreathSessionService liveSessionService;
  final BreathTelemetryService telemetryService;
  final TokenNotifier tokenNotifier;
  final SyncEngine syncEngine;
  final SyncGrpcListener syncGrpcListener;
  final AppLifecycleService appLifecycleService;

  App._({
    required this.db,
    required this.grpcClient,
    required this.userApi,
    required this.statsApi,
    required this.tokenApi,
    required this.syncApi,
    required this.userRepository,
    required this.breathSessionRepository,
    required this.userNotifier,
    required this.breathSessionNotifier,
    required this.deeplinkRouter,
    required this.appSettingsNotifier,
    required this.liveGrpcService,
    required this.liveSessionNotifier,
    required this.liveSessionService,
    required this.telemetryService,
    required this.tokenNotifier,
    required this.syncEngine,
    required this.syncGrpcListener,
    required this.appLifecycleService,
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

    final appLifecycleService = AppLifecycleService();
    final grpcAuthInterceptor = GrpcAuthInterceptor(storage: const FlutterSecureStorage(), logoutNotifier: logoutNotifier);
    final grpcClient = GrpcClient(host: Environment.instance.grpcHost, port: Environment.instance.grpcPort, isSecure: Environment.instance.grpcSecure, detachStream: appLifecycleService.onDetach, interceptors: [grpcAuthInterceptor]);
    final authApi = AuthApi(grpcClient.authService, const FlutterSecureStorage());
    final statsApi = StatsApi(grpcClient.statsService);
    final userApi = UserApi(grpcClient.userService, grpcClient.breathSessionService);
    final tokenApi = PersonalAccessTokenApi(grpcClient.authService);
    final breathSessionApi = BreathSessionApi(grpcClient.breathSessionService);
    final syncApi = SyncApi(grpcClient.syncService, grpcClient.breathSessionService);

    final deviceApi = DeviceApi(grpcClient.deviceService);
    unawaited(DeviceRepository(api: deviceApi, storage: SecureStorage()).ping());

    final userRepository = UserRepository(userDao: db.userDao, api: authApi, userApi: userApi, google: GoogleAuthProvider(), storage: SecureStorage());
    final breathSessionRepository = BreathSessionRepository(dao: db.breathSessionDao, api: breathSessionApi);

    final initialUser = await userRepository.loadUser();
    final userNotifier = UserNotifier(repository: userRepository, logoutNotifier: logoutNotifier, initialUser: initialUser);
    final breathSessionNotifier = BreathSessionNotifier(repository: breathSessionRepository, authStream: userNotifier.stream);
    final syncEngine = SyncEngine(syncApi: syncApi, syncStateDao: db.syncStateDao, breathSessionDao: db.breathSessionDao, breathSessionNotifier: breathSessionNotifier, authStream: userNotifier.stream);
    await syncEngine.waitForColdStart(!initialUser.isGuest);

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

    final liveGrpcService = LiveSessionGrpcService(liveService: grpcClient.liveService, telemetryService: grpcClient.telemetryService, authStream: userNotifier.stream, connectivityStream: Connectivity().onConnectivityChanged, resumeStream: appLifecycleService.onResume);
    final syncGrpcListener = SyncGrpcListener(syncService: grpcClient.syncService, syncEngine: syncEngine, syncStateDao: db.syncStateDao, authStream: userNotifier.stream);

    final liveSessionNotifier = LiveBreathSessionNotifier(liveSessionService: liveGrpcService, authStream: userNotifier.stream);
    final liveSessionService = LiveBreathSessionService(notifier: liveSessionNotifier);
    final telemetryService = BreathTelemetryService(liveSessionService: liveGrpcService);
    final tokenNotifier = TokenNotifier(api: tokenApi);

    shared = App._(
      db: db,
      grpcClient: grpcClient,
      userApi: userApi,
      statsApi: statsApi,
      tokenApi: tokenApi,
      syncApi: syncApi,
      userRepository: userRepository,
      breathSessionRepository: breathSessionRepository,
      userNotifier: userNotifier,
      breathSessionNotifier: breathSessionNotifier,
      deeplinkRouter: deeplinkRouter,
      appSettingsNotifier: appSettingsNotifier,
      liveGrpcService: liveGrpcService,
      liveSessionNotifier: liveSessionNotifier,
      liveSessionService: liveSessionService,
      telemetryService: telemetryService,
      tokenNotifier: tokenNotifier,
      syncEngine: syncEngine,
      syncGrpcListener: syncGrpcListener,
      appLifecycleService: appLifecycleService,
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
        return GlobalListeners(
          sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream,
          authErrorStream: App.shared.userNotifier.authErrorStream,
          child: child!,
        );
      },
    );
  }
}
