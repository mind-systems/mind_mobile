import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListCellModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListState.dart';

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
  final int pageSize;

  int _currentPage = 0;
  StreamSubscription<BreathSessionListEvent>? _subscription;

  void Function(SessionListError error)? onErrorEvent;

  BreathSessionListViewModel({required this.service, this.pageSize = 50})
      : super(
          const BreathSessionListState(
            items: [],
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

  void _handlePageLoaded(PageLoadedEvent event) {
    final newItems = _transformDTOsToModels(event.items);
    final updatedItems = event.page == 0 ? newItems : [...state.items, ...newItems];

    state = BreathSessionListState(
      items: updatedItems,
      mode: updatedItems.isEmpty
          ? BreathSessionListMode.empty
          : BreathSessionListMode.content,
      hasMore: event.hasMore,
    );
  }

  void _handleSessionsRefreshed(SessionsRefreshedEvent event) {
    final items = _transformDTOsToModels(event.items);

    state = BreathSessionListState(
      items: items,
      mode: items.isEmpty
          ? BreathSessionListMode.empty
          : BreathSessionListMode.content,
      hasMore: event.hasMore,
    );

    _currentPage = 0;
  }

  void _handleSessionCreated(SessionCreatedEvent event) {
    final newItem = _dtoToCellModel(event.session);
    state = state.copyWith(items: [newItem, ...state.items]);
  }

  void _handleSessionUpdated(SessionUpdatedEvent event) {
    final updatedItem = _dtoToCellModel(event.session);
    final updatedItems = [
      for (final item in state.items)
        if (item.id == event.session.id) updatedItem else item
    ];
    state = state.copyWith(items: updatedItems);
  }

  void _handleSessionDeleted(SessionDeletedEvent event) {
    final items = state.items.where((item) => item.id != event.id).toList();
    state = state.copyWith(
      items: items,
      mode: items.isEmpty ? BreathSessionListMode.empty : BreathSessionListMode.content,
    );
  }

  Future<void> _loadInitialPage() async {
    try {
      await service.fetchPage(0, pageSize);
      _currentPage = 0;
    } catch (e) {
      onErrorEvent?.call(SessionListError.loadFailed);
      state = const BreathSessionListState(
        items: [],
        mode: BreathSessionListMode.empty,
        hasMore: false,
      );
    }
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isPaging) return;

    state = state.copyWith(mode: BreathSessionListMode.paging);

    try {
      await service.fetchPage(_currentPage + 1, pageSize);
      _currentPage++;
    } catch (e) {
      onErrorEvent?.call(SessionListError.pagingFailed);
      state = state.copyWith(mode: BreathSessionListMode.content);
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
    List<BreathSessionListCellModel>? items,
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
