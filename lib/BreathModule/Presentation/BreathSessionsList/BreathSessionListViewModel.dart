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
  StreamSubscription<List<BreathSessionListItemDTO>>? _subscription;

  void Function(SessionListError error)? onErrorEvent;

  BreathSessionListViewModel({required this.service, this.pageSize = 50})
      : super(
          const BreathSessionListState(
            items: [],
            mode: BreathSessionListMode.initialLoading,
            hasMore: true,
          ),
        ) {
    _subscription = service.observeChanges().listen(_onDataChanged);
    _loadInitialPage();
  }

  void _onDataChanged(List<BreathSessionListItemDTO> dtos) {
    final cellModels = _transformDTOsToModels(dtos);

    if (state.mode == BreathSessionListMode.initialLoading) {
      state = BreathSessionListState(
        items: cellModels,
        mode: cellModels.isEmpty
            ? BreathSessionListMode.empty
            : BreathSessionListMode.content,
        hasMore: dtos.length >= pageSize,
      );
    } else if (state.mode == BreathSessionListMode.paging) {
      state = BreathSessionListState(
        items: cellModels,
        mode: BreathSessionListMode.content,
        hasMore: dtos.length >= pageSize,
      );
    } else if (state.mode == BreathSessionListMode.syncing) {
      state = BreathSessionListState(
        items: cellModels,
        mode: cellModels.isEmpty
            ? BreathSessionListMode.empty
            : BreathSessionListMode.content,
        hasMore: dtos.length >= pageSize,
      );
      _currentPage = 0;
    } else {
      state = state.copyWith(items: cellModels);
    }
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
      await service.syncSessions(pageSize);
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
