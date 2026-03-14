// Скопируйте этот файл в Environment.dart и заполните своими значениями
// cp lib/Core/Environment.example.dart lib/Core/Environment.dart

class Environment {
  final String name;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final bool isProduction;
  final String googleIosClientId;
  final String googleAndroidClientId;
  final String googleServerClientId;

  Environment._({
    required this.name,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.isProduction,
    required this.googleIosClientId,
    required this.googleAndroidClientId,
    required this.googleServerClientId,
  });

  static late Environment _instance;

  static Environment get instance => _instance;

  static void initDev() {
    _instance = Environment._(
      name: 'Development',
      apiBaseUrl: 'http://localhost:3000', // Замените на ваш development URL
      wsBaseUrl: 'ws://localhost:3000',    // Замените на ваш development WS URL
      isProduction: false,
      googleIosClientId: 'YOUR_DEV_IOS_CLIENT_ID',
      googleAndroidClientId: 'YOUR_DEV_ANDROID_CLIENT_ID',
      googleServerClientId: 'YOUR_DEV_SERVER_CLIENT_ID',
    );
  }

  static void initProd() {
    _instance = Environment._(
      name: 'Production',
      apiBaseUrl: 'https://your-api.com',    // Замените на ваш production URL
      wsBaseUrl: 'wss://your-api.com',       // Замените на ваш production WS URL
      isProduction: true,
      googleIosClientId: 'YOUR_PROD_IOS_CLIENT_ID',
      googleAndroidClientId: 'YOUR_PROD_ANDROID_CLIENT_ID',
      googleServerClientId: 'YOUR_PROD_SERVER_CLIENT_ID',
    );
  }
}
