class BreathSessionListCellModel {
  final String id;

  /// Дескрипшн сессии (1–2 строки)
  final String title;

  /// Строка паттернов дыхания: "● 4-4-4-4   ■ 6-6   ▲ 4-2-6"
  final String subtitle;

  /// Общая длительность сессии: "12:40"
  final String duration;

  const BreathSessionListCellModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
  });
}
