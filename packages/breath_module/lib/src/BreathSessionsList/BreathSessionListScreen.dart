import 'package:flutter/material.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'BreathSessionListViewModel.dart';
import 'Models/BreathSessionListItem.dart';
import 'Models/BreathSessionListState.dart';
import 'Views/BreathSessionListCell.dart';
import 'Views/BreathSessionListSectionHeader.dart';
import 'Views/BreathSessionListSkeletonCell.dart';
import 'package:mind_ui/mind_ui.dart';

class BreathSessionListScreen extends ConsumerStatefulWidget {
  const BreathSessionListScreen({super.key});

  static String name = 'breath_session_list';
  static String path = '/$name';

  @override
  ConsumerState<BreathSessionListScreen> createState() =>
      _BreathSessionListViewState();
}

class _BreathSessionListViewState extends ConsumerState<BreathSessionListScreen> {
  late final ScrollController _scrollController;

  // Примерная высота одной ячейки для расчёта порога пагинации
  static const double _estimatedCellHeight = 109.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _setupErrorListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupErrorListener() {
    final viewModel = ref.read(breathSessionListViewModelProvider.notifier);
    viewModel.onErrorEvent = (error) {
      final l10n = AppLocalizations.of(context)!;
      final message = switch (error) {
        SessionListError.loadFailed => l10n.breathSessionListLoadFailed,
        SessionListError.pagingFailed => l10n.breathSessionListPagingFailed,
        SessionListError.syncFailed => l10n.breathSessionListSyncFailed,
      };

      ref.read(globalSnackBarNotifierProvider.notifier).show(
        SnackBarEvent.error(message),
      );
    };
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final threshold = _scrollController.position.maxScrollExtent - (10 * _estimatedCellHeight);

    if (_scrollController.position.pixels >= threshold) {
      ref.read(breathSessionListViewModelProvider.notifier).loadNextPage();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(breathSessionListViewModelProvider.notifier).refresh();
  }

  void _onSessionTap(String sessionId) {
    ref.read(breathSessionListViewModelProvider.notifier).onSessionTap(sessionId);
  }

  void _onCreateTap() {
    ref.read(breathSessionListViewModelProvider.notifier).onCreateTap();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(breathSessionListViewModelProvider);

    return Scaffold(
      body: SafeArea(child: _buildBody(state)),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreateTap,
        mini: true,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BreathSessionListState state) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      backgroundColor: Theme.of(context).cardColor,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          final isLastInSection = index == state.items.length - 1 ||
              state.items[index + 1] is! BreathSessionListCellModel;

          return switch (item) {
            BreathSessionListCellModel cell => GestureDetector(
              onTap: () => _onSessionTap(cell.id),
              child: BreathSessionListCell(
                model: cell,
                showDivider: !isLastInSection,
              ),
            ),
            SectionHeaderModel header => BreathSessionListSectionHeader(
              title: switch (header.type) {
                SectionHeaderType.mySessions =>
                  AppLocalizations.of(context)!.breathSessionListMySessions,
                SectionHeaderType.starredSessions =>
                  AppLocalizations.of(context)!.breathSessionListStarredSessions,
                SectionHeaderType.sharedSessions =>
                  AppLocalizations.of(context)!.breathSessionListSharedSessions,
              },
            ),
            SkeletonCellModel skeleton => BreathSessionListSkeletonCell(
              animated: skeleton.animated,
            ),
          };
        },
      ),
    );
  }
}
