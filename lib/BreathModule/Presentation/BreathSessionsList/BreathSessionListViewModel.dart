import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListCoordinator.dart';

enum SessionListError { loadFailed, pagingFailed, syncFailed }

final breathSessionListViewModelProvider =
    StateNotifierProvider<BreathSessionListViewModel, BreathSessionListState>((
      ref,
    ) {
      throw UnimplementedError(
        'BreathSessionListViewModel должен быть передан через override в модуле',
      );
    });

class BreathSessionListViewModel extends StateNotifier<BreathSessionListState> {
  final IBreathSessionListService service;
  final IBreathSessionListCoordinator coordinator;
  final int pageSize;

  int _currentPage = 0;
  StreamSubscription<BreathSessionListEvent>? _subscription;

  void Function(SessionListError error)? onErrorEvent;

  BreathSessionListViewModel({required this.service, required this.coordinator, this.pageSize = 50})
      : super(
         BreathSessionListState(
           items: [SkeletonCellModel(animated: true)],
           mode: BreathSessionListMode.initialLoading,
           hasMore: true,
         ),
       ) {
    _subscription = service.observeChanges().listen(_onEvent);
    _loadInitialPage();
  }

  void _onEvent(BreathSessionListEvent event) {
    switch (event) {
      case PageLoadedEvent e:
        _handlePageLoaded(e);
        break;

      case SessionsRefreshedEvent e:
        _handleSessionsRefreshed(e);
        break;

      case SessionsInvalidatedEvent _:
        _handleSessionsInvalidated();
        break;

      case SessionCreatedEvent e:
        _handleSessionCreated(e);
        break;

      case SessionUpdatedEvent e:
        _handleSessionUpdated(e);
        break;

      case SessionDeletedEvent e:
        _handleSessionDeleted(e);
        break;
    }
  }

  void _handleSessionsInvalidated() {
    _currentPage = 0;
    state = BreathSessionListState(
      items: [SkeletonCellModel(animated: true)],
      mode: BreathSessionListMode.initialLoading,
      hasMore: true,
    );
    _loadInitialPage();
  }

  void _handlePageLoaded(PageLoadedEvent event) {
    final cellModels = _transformDTOsToModels(event.items);

    if (event.page == 0) {
      // Первая страница
      state = BreathSessionListState(
        items: cellModels.isEmpty
            ? [SkeletonCellModel(animated: false)]
            : _buildItemsWithSections(cellModels),
        mode: cellModels.isEmpty
            ? BreathSessionListMode.empty
            : BreathSessionListMode.content,
        hasMore: event.hasMore,
      );
    } else {
      // Пагинация - добавляем к существующим
      final currentCells = _extractCellModels(state.items);
      final allCells = [...currentCells, ...cellModels];

      state = BreathSessionListState(
        items: _buildItemsWithSections(allCells),
        mode: BreathSessionListMode.content,
        hasMore: event.hasMore,
      );
    }
  }

  void _handleSessionsRefreshed(SessionsRefreshedEvent event) {
    final cellModels = _transformDTOsToModels(event.items);

    state = BreathSessionListState(
      items: cellModels.isEmpty
          ? [SkeletonCellModel(animated: false)]
          : _buildItemsWithSections(cellModels),
      mode: cellModels.isEmpty
          ? BreathSessionListMode.empty
          : BreathSessionListMode.content,
      hasMore: event.hasMore,
    );

    _currentPage = 0;
  }

  void _handleSessionCreated(SessionCreatedEvent event) {
    final newCell = _dtoToCellModel(event.session);
    final currentCells = _extractCellModels(state.items);
    final allCells = [newCell, ...currentCells];

    state = state.copyWith(
      items: _buildItemsWithSections(allCells),
      mode: BreathSessionListMode.content,
    );
  }

  void _handleSessionUpdated(SessionUpdatedEvent event) {
    final updatedCell = _dtoToCellModel(event.session);
    final currentCells = _extractCellModels(state.items);

    final updatedCells = [
      for (final cell in currentCells)
        if (cell.id == event.session.id) updatedCell else cell
    ];

    state = state.copyWith(items: _buildItemsWithSections(updatedCells));
  }

  void _handleSessionDeleted(SessionDeletedEvent event) {
    final currentCells = _extractCellModels(state.items);
    final remainingCells = currentCells.where((cell) => cell.id != event.id).toList();

    state = state.copyWith(
      items: remainingCells.isEmpty
          ? [SkeletonCellModel(animated: false)]
          : _buildItemsWithSections(remainingCells),
      mode: remainingCells.isEmpty
          ? BreathSessionListMode.empty
          : BreathSessionListMode.content,
    );
  }

  Future<void> _loadInitialPage() async {
    try {
      await service.fetchPage(0, pageSize);
      _currentPage = 0;
    } catch (e) {
      onErrorEvent?.call(SessionListError.loadFailed);
      state = BreathSessionListState(
        items: [SkeletonCellModel(animated: false)],
        mode: BreathSessionListMode.empty,
        hasMore: false,
      );
    }
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isPaging) return;

    // Добавляем skeleton в конец
    final itemsWithLoader = [...state.items, SkeletonCellModel(animated: true)];
    state = state.copyWith(
      items: itemsWithLoader,
      mode: BreathSessionListMode.paging,
    );

    try {
      await service.fetchPage(_currentPage + 1, pageSize);
      _currentPage++;
    } catch (e) {
      onErrorEvent?.call(SessionListError.pagingFailed);
      // Убираем skeleton обратно
      final itemsWithoutLoader = state.items
          .where((item) => item is! SkeletonCellModel)
          .toList();
      state = state.copyWith(
        items: itemsWithoutLoader,
        mode: BreathSessionListMode.content,
      );
    }
  }

  Future<void> sync() async {
    state = state.copyWith(mode: BreathSessionListMode.syncing);

    try {
      await service.refresh(pageSize);
    } catch (e) {
      onErrorEvent?.call(SessionListError.syncFailed);
      state = state.copyWith(mode: BreathSessionListMode.content);
    }
  }

  void onSessionTap(String sessionId) {
    coordinator.openSession(sessionId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Извлекает только ячейки с данными из items (без headers/skeletons)
  List<BreathSessionListCellModel> _extractCellModels(
    List<BreathSessionListItem> items,
  ) {
    return items.whereType<BreathSessionListCellModel>().toList();
  }

  /// Строит финальный список items с секциями
  /// mine (без хедера) → shared (с хедером "Shared Sessions")
  List<BreathSessionListItem> _buildItemsWithSections(
    List<BreathSessionListCellModel> cells,
  ) {
    final result = <BreathSessionListItem>[];
    SessionOwnership? lastOwnership;

    for (final cell in cells) {
      // При переходе на shared вставляем хедер
      if (cell.ownership == SessionOwnership.shared &&
          lastOwnership != SessionOwnership.shared) {
        result.add(SectionHeaderModel('Shared Sessions'));
      }

      result.add(cell);
      lastOwnership = cell.ownership;
    }

    return result;
  }

  List<BreathSessionListCellModel> _transformDTOsToModels(
    List<BreathSessionListItemDTO> dtos,
  ) {
    return dtos.map(_dtoToCellModel).toList();
  }

  BreathSessionListCellModel _dtoToCellModel(BreathSessionListItemDTO dto) {
    return BreathSessionListCellModel(
      id: dto.id,
      title: dto.description,
      subtitle: _formatPatterns(dto.patterns),
      duration: _formatDuration(dto.totalDurationSeconds),
      ownership: dto.ownership,
    );
  }

  String _formatPatterns(List<BreathPatternDTO> patterns) {
    if (patterns.isEmpty) return '';

    final patternStrings = patterns.map((pattern) {
      final shape = _getShapeSymbol(pattern.shape);
      final durations = pattern.durations.join('-');
      final repeatSuffix = pattern.repeatCount > 1 ? ' ×${pattern.repeatCount}' : '';
      return '$shape $durations$repeatSuffix';
    }).toList();

    return patternStrings.join('   ');
  }

  String _getShapeSymbol(BreathPatternShape shape) {
    switch (shape) {
      case BreathPatternShape.circle:
        return '●';
      case BreathPatternShape.square:
        return '■';
      case BreathPatternShape.triangleUp:
        return '▲';
      case BreathPatternShape.triangleDown:
        return '▼';
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

extension _BreathSessionListStateExtension on BreathSessionListState {
  BreathSessionListState copyWith({
    List<BreathSessionListItem>? items,
    BreathSessionListMode? mode,
    bool? hasMore,
  }) {
    return BreathSessionListState(
      items: items ?? this.items,
      mode: mode ?? this.mode,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
