// Скопируйте этот файл в Environment.dart и заполните своими значениями
// cp lib/Core/Environment.example.dart lib/Core/Environment.dart

class Environment {
  final String name;
  final String apiBaseUrl;
  final bool isProduction;

  Environment._({
    required this.name,
    required this.apiBaseUrl,
    required this.isProduction,
  });

  static late Environment _instance;

  static Environment get instance => _instance;

  static void initDev() {
    _instance = Environment._(
      name: 'Development',
      apiBaseUrl: 'http://localhost:3000', // Замените на ваш devepopment URL
      isProduction: false,
    );
  }

  static void initProd() {
    _instance = Environment._(
      name: 'Production',
      apiBaseUrl:
          'https://your-api.com', // Замените на ваш production URL
      isProduction: true,
    );
  }
}
