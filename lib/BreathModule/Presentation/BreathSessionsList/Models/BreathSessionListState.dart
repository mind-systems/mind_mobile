import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListCellModel.dart';

enum BreathSessionListMode {
  initialLoading, // нет данных, первый вход → shimmer
  content,        // нормальный список
  paging,         // подгрузка следующей страницы
  syncing,        // pull-to-refresh / тотальный синк
  empty,          // данных нет, но без shimmer (статичные шаблоны)
}

class BreathSessionListState {
  final List<BreathSessionListCellModel> items;
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
