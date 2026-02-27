import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Views/BreathSessionListCell.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Views/BreathSessionListSectionHeader.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Views/BreathSessionListSkeletonCell.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/Views/SnackBarModule/GlobalSnackBarNotifier.dart';
import 'package:mind/Views/SnackBarModule/Models/SnackBarEvent.dart';

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
      final message = switch (error) {
        SessionListError.loadFailed => 'Failed to load sessions',
        SessionListError.pagingFailed => 'Failed to load more sessions',
        SessionListError.syncFailed => 'Failed to sync sessions',
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
    await ref.read(breathSessionListViewModelProvider.notifier).sync();
  }

  void _onSessionTap(String sessionId) {
    ref.read(breathSessionListViewModelProvider.notifier).onSessionTap(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(breathSessionListViewModelProvider);

    return Scaffold(
      body: SafeArea(child: _buildBody(state)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(OnboardingScreen.path),
        child: const Text('+'),
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

          return switch (item) {
            BreathSessionListCellModel cell => GestureDetector(
              onTap: () => _onSessionTap(cell.id),
              child: BreathSessionListCell(model: cell),
            ),
            SectionHeaderModel header => BreathSessionListSectionHeader(
              title: header.title,
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
