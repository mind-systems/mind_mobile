import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'IBreathSessionListService.dart';
import 'Models/BreathSessionListItem.dart';
import 'Models/BreathSessionListItemDTO.dart';
import 'Models/BreathSessionListState.dart';
import 'IBreathSessionListCoordinator.dart';

enum SessionListError { loadFailed, syncFailed }

final breathSessionListViewModelProvider =
    NotifierProvider<BreathSessionListViewModel, BreathSessionListState>(() {
      throw UnimplementedError(
        'BreathSessionListViewModel must be overridden via ProviderScope',
      );
    });

class BreathSessionListViewModel extends Notifier<BreathSessionListState> {
  final IBreathSessionListService service;
  final IBreathSessionListCoordinator coordinator;
  final int pageSize;

  void Function(SessionListError error)? onErrorEvent;

  BreathSessionListViewModel({required this.service, required this.coordinator, this.pageSize = 50});

  @override
  BreathSessionListState build() {
    final subscription = service.observeChanges().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());

    _loadInitialPage(); // write-through refresh in background

    final cached = service.currentItems();
    if (cached.isNotEmpty) {
      return BreathSessionListState(
        items: _buildItemsWithSections(_transformDTOsToModels(cached)),
        mode: BreathSessionListMode.content,
        hasMore: false,
      );
    }

    return BreathSessionListState(
      items: [SkeletonCellModel(animated: true)],
      mode: BreathSessionListMode.initialLoading,
      hasMore: false,
    );
  }

  void _onEvent(BreathSessionListEvent event) {
    switch (event) {
      case ListUpdatedEvent e:
        _handleListUpdated(e);
        break;

      case SessionsInvalidatedEvent _:
        _handleSessionsInvalidated();
        break;
    }
  }

  void _handleSessionsInvalidated() {
    state = BreathSessionListState(
      items: [SkeletonCellModel(animated: true)],
      mode: BreathSessionListMode.initialLoading,
      hasMore: false,
    );
    _loadInitialPage();
  }

  void _handleListUpdated(ListUpdatedEvent event) {
    final cells = _transformDTOsToModels(event.items);

    if (cells.isEmpty) {
      state = BreathSessionListState(
        items: [SkeletonCellModel(animated: false)],
        mode: BreathSessionListMode.empty,
        hasMore: false,
      );
    } else {
      state = BreathSessionListState(
        items: _buildItemsWithSections(cells),
        mode: BreathSessionListMode.content,
        hasMore: false,
      );
    }
  }

  Future<void> _loadInitialPage() async {
    try {
      await service.refresh(pageSize);
    } catch (e) {
      if (state.mode == BreathSessionListMode.initialLoading) {
        // Nothing rendered from Drift yet — surface the error and show empty.
        onErrorEvent?.call(SessionListError.loadFailed);
        state = BreathSessionListState(
          items: [SkeletonCellModel(animated: false)],
          mode: BreathSessionListMode.empty,
          hasMore: false,
        );
      }
      // If content is already visible from Drift, fail silently.
    }
  }

  /// No-op — hasMore is always false so scroll pagination never fires.
  Future<void> loadNext() async {
    if (!state.hasMore || state.isPaging) return;
  }

  Future<void> refresh() async {
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

  void onCreateTap() {
    coordinator.openConstructor();
  }

  /// Builds the final items list with 3 sections in fixed order:
  /// STARRED → MINE → SHARED, preserving arrival order within each group.
  List<BreathSessionListItem> _buildItemsWithSections(
    List<BreathSessionListCellModel> cells,
  ) {
    final starred = cells.where((c) => c.section == ListSection.starred).toList();
    final mine = cells.where((c) => c.section == ListSection.mine).toList();
    final shared = cells.where((c) => c.section == ListSection.shared).toList();

    final result = <BreathSessionListItem>[];

    if (starred.isNotEmpty) {
      result.add(SectionHeaderModel(SectionHeaderType.starredSessions));
      result.addAll(starred);
    }

    if (mine.isNotEmpty) {
      result.add(SectionHeaderModel(SectionHeaderType.mySessions));
      result.addAll(mine);
    }

    if (shared.isNotEmpty) {
      result.add(SectionHeaderModel(SectionHeaderType.sharedSessions));
      result.addAll(shared);
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
      complexity: dto.complexity,
      ownership: dto.ownership,
      isStarred: dto.isStarred,
      section: dto.section,
    );
  }

  String _formatPatterns(List<BreathPatternDTO> patterns) {
    final visible = patterns.where((p) => !p.isRestOnly).toList();

    if (visible.isEmpty) return '';

    final patternStrings = visible.map((pattern) {
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
