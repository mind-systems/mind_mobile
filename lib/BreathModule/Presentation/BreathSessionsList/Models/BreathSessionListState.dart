import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';

enum BreathSessionListMode {
  initialLoading, // первый вход → одна анимированная skeleton
  content,        // нормальный список с данными
  paging,         // подгрузка следующей страницы → skeleton в конце
  syncing,        // pull-to-refresh / тотальный синк
  empty,          // данных нет → одна статичная skeleton
}

class BreathSessionListState {
  final List<BreathSessionListItem> items;
  final BreathSessionListMode mode;
  final bool hasMore;

  const BreathSessionListState({
    required this.items,
    required this.mode,
    required this.hasMore,
  });

  bool get isInitialLoading => mode == BreathSessionListMode.initialLoading;
  bool get isPaging => mode == BreathSessionListMode.paging;
  bool get isSyncing => mode == BreathSessionListMode.syncing;
  bool get isEmpty => mode == BreathSessionListMode.empty;
}
