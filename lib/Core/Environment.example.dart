// Скопируйте этот файл в Environment.dart и заполните своими значениями
// cp lib/Core/Environment.example.dart lib/Core/Environment.dart

class Environment {
  final String name;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String deeplinkUrl;
  final String linkDomain;
  final String iosBundleId;
  final String androidPackageName;
  final bool isProduction;
  final String googleIosClientId;
  final String googleAndroidClientId;
  final String googleServerClientId;
  final String googleIosClientIdPlain;
  final String googleServerClientIdPlain;
  final String googleOAuthCallbackScheme;
  final String deeplinkScheme;
  final String grpcHost;
  final int grpcPort;
  final bool grpcSecure;

  Environment._({
    required this.name,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.deeplinkUrl,
    required this.linkDomain,
    required this.iosBundleId,
    required this.androidPackageName,
    required this.isProduction,
    required this.googleIosClientId,
    required this.googleAndroidClientId,
    required this.googleServerClientId,
    required this.googleIosClientIdPlain,
    required this.googleServerClientIdPlain,
    required this.googleOAuthCallbackScheme,
    required this.deeplinkScheme,
    required this.grpcHost,
    required this.grpcPort,
    required this.grpcSecure,
  });

  static late Environment _instance;

  static Environment get instance => _instance;

  static void initDev() {
    _instance = Environment._(
      name: 'Development',
      apiBaseUrl: 'http://localhost:3000', // Замените на ваш development URL
      wsBaseUrl: 'ws://localhost:3000',    // Замените на ваш development WS URL
      deeplinkUrl: 'https://YOUR_DEV_DEEPLINK_URL',
      linkDomain: 'YOUR_DEV_LINK_DOMAIN',
      iosBundleId: 'YOUR_DEV_IOS_BUNDLE_ID',
      androidPackageName: 'YOUR_DEV_ANDROID_PACKAGE_NAME',
      isProduction: false,
      googleIosClientId: 'YOUR_DEV_IOS_CLIENT_ID.apps.googleusercontent.com',
      googleAndroidClientId: 'YOUR_DEV_ANDROID_CLIENT_ID.apps.googleusercontent.com',
      googleServerClientId: 'YOUR_DEV_SERVER_CLIENT_ID.apps.googleusercontent.com',
      googleIosClientIdPlain: 'YOUR_DEV_IOS_CLIENT_ID',
      googleServerClientIdPlain: 'YOUR_DEV_SERVER_CLIENT_ID',
      googleOAuthCallbackScheme: 'com.googleusercontent.apps.YOUR_DEV_IOS_CLIENT_ID',
      deeplinkScheme: 'mind-dev',
      grpcHost: 'YOUR_DEV_GRPC_HOST',
      grpcPort: 50051,
      grpcSecure: false,
    );
  }

  static void initProd() {
    _instance = Environment._(
      name: 'Production',
      apiBaseUrl: 'https://your-api.com',    // Замените на ваш production URL
      wsBaseUrl: 'wss://your-api.com',       // Замените на ваш production WS URL
      deeplinkUrl: 'https://YOUR_PROD_DEEPLINK_URL',
      linkDomain: 'YOUR_PROD_LINK_DOMAIN',
      iosBundleId: 'YOUR_PROD_IOS_BUNDLE_ID',
      androidPackageName: 'YOUR_PROD_ANDROID_PACKAGE_NAME',
      isProduction: true,
      googleIosClientId: 'YOUR_PROD_IOS_CLIENT_ID.apps.googleusercontent.com',
      googleAndroidClientId: 'YOUR_PROD_ANDROID_CLIENT_ID.apps.googleusercontent.com',
      googleServerClientId: 'YOUR_PROD_SERVER_CLIENT_ID.apps.googleusercontent.com',
      googleIosClientIdPlain: 'YOUR_PROD_IOS_CLIENT_ID',
      googleServerClientIdPlain: 'YOUR_PROD_SERVER_CLIENT_ID',
      googleOAuthCallbackScheme: 'com.googleusercontent.apps.YOUR_PROD_IOS_CLIENT_ID',
      deeplinkScheme: 'mind',
      grpcHost: 'YOUR_PROD_GRPC_HOST',
      grpcPort: 443,
      grpcSecure: true,
    );
  }
}
