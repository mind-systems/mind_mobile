import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Views/BreathSessionListCell.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Views/BreathSessionListSkeletonCell.dart';
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

    final threshold = _scrollController.position.maxScrollExtent -
        (10 * _estimatedCellHeight);

    if (_scrollController.position.pixels >= threshold) {
      ref.read(breathSessionListViewModelProvider.notifier).loadNextPage();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(breathSessionListViewModelProvider.notifier).sync();
  }

  void _onSessionTap(String sessionId) {
    context.push(BreathSessionScreen.path, extra: sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(breathSessionListViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(BreathSessionListState state) {
    // Initial loading - показываем одну анимированную skeleton ячейку
    if (state.mode == BreathSessionListMode.initialLoading) {
      return ListView(
        children: const [
          BreathSessionListSkeletonCell(animated: true),
        ],
      );
    }

    // Empty state - показываем одну статичную skeleton ячейку
    if (state.mode == BreathSessionListMode.empty) {
      return ListView(
        children: const [
          BreathSessionListSkeletonCell(animated: false),
        ],
      );
    }

    // Content with pull-to-refresh
    return RefreshIndicator(
      onRefresh: _onRefresh,
      backgroundColor: const Color(0xFF1A2433),
      color: const Color(0xFF00D9FF),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.items.length + (state.isPaging ? 1 : 0),
        itemBuilder: (context, index) {
          // Skeleton ячейка для пагинации
          if (index == state.items.length && state.isPaging) {
            return const BreathSessionListSkeletonCell(animated: true);
          }

          // Обычная ячейка с данными
          final model = state.items[index];
          return GestureDetector(
            onTap: () => _onSessionTap(model.id),
            child: BreathSessionListCell(model: model),
          );
        },
      ),
    );
  }
}
