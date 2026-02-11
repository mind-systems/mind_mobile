sealed class BreathSessionListItem {}

/// Ячейка с данными сессии
class BreathSessionListCellModel extends BreathSessionListItem {
  final String id;
  /// Дескрипшн сессии (1–2 строки)
  final String title;
  /// Строка паттернов дыхания: "● 4-4-4-4   ■ 6-6   ▲ 4-2-6"
  final String subtitle;
  /// Общая длительность сессии: "12:40"
  final String duration;
  /// Тип владения сессией (используется VM для группировки)
  final SessionOwnership ownership;

  BreathSessionListCellModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.ownership,
  });
}

/// Заголовок секции (разделитель групп)
class SectionHeader extends BreathSessionListItem {
  final String title;
  SectionHeader(this.title);
}

/// Skeleton-ячейка (для initial/empty/paging)
class SkeletonCell extends BreathSessionListItem {
  final bool animated;
  SkeletonCell({required this.animated});
}

/// Тип владения сессией
enum SessionOwnership {
  /// Сессия создана текущим пользователем
  mine,
  /// Публичная сессия другого пользователя
  shared,
}
