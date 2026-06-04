import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/IHomeCoordinator.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/IHomeService.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeState.dart';

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  () => throw UnimplementedError(
    'HomeViewModel must be overridden at ProviderScope',
  ),
);

class HomeViewModel extends Notifier<HomeState> {
  final IHomeService service;
  final IHomeCoordinator coordinator;

  HomeViewModel({required this.service, required this.coordinator});

  Timer? _suggestionsRetryTimer;
  Timer? _statsRetryTimer;
  int _suggestionsRetryAttempt = 0;
  int _statsRetryAttempt = 0;
  int _suggestionsLoadGeneration = 0;
  int _statsLoadGeneration = 0;

  static const Duration _retryBaseDelay = Duration(seconds: 2);
  static const Duration _retryMaxDelay = Duration(seconds: 30);

  bool _isNetworkError(Object e) =>
      e is TimeoutException ||
      (e is GrpcError && e.code == StatusCode.unavailable);

  Duration _retryDelay(int attempt) {
    final factor = 1 << attempt.clamp(0, 4);
    final ms = (_retryBaseDelay.inMilliseconds * factor)
        .clamp(0, _retryMaxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  @override
  HomeState build() {
    final subscription = service.observeChanges().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());
    ref.onDispose(() {
      _suggestionsRetryTimer?.cancel();
      _statsRetryTimer?.cancel();
    });

    Future.microtask(() => _loadInitialData());

    return HomeState.initial().copyWith(isGuest: service.isGuest);
  }

  void _loadInitialData() {
    _loadSuggestions();
    _loadStats();
  }

  Future<void> _loadSuggestions() async {
    _suggestionsRetryTimer?.cancel();
    final gen = ++_suggestionsLoadGeneration;
    state = state.copyWith(isSuggestionsLoading: true);
    try {
      final suggestions = await service.fetchSuggestions();
      if (gen != _suggestionsLoadGeneration) return;
      _suggestionsRetryAttempt = 0;
      state = state.copyWith(suggestions: suggestions, isSuggestionsLoading: false);
    } catch (e) {
      if (gen != _suggestionsLoadGeneration) return;
      if (_isNetworkError(e)) {
        // Keep isSuggestionsLoading = true so the shimmer persists, and retry —
        // unary failures don't trigger HomeGrpcReconnected while connectivity is intact.
        _suggestionsRetryTimer =
            Timer(_retryDelay(_suggestionsRetryAttempt++), _loadSuggestions);
        return;
      }
      state = state.copyWith(isSuggestionsLoading: false, error: e.toString());
    }
  }

  Future<void> _loadStats() async {
    _statsRetryTimer?.cancel();
    final gen = ++_statsLoadGeneration;
    state = state.copyWith(isStatsLoading: true);
    try {
      final stats = await service.fetchStats();
      if (gen != _statsLoadGeneration) return;
      _statsRetryAttempt = 0;
      if (stats != null) {
        state = state.copyWith(stats: stats, isStatsLoading: false);
      } else {
        state = state.copyWith(isStatsLoading: false);
      }
    } catch (e) {
      if (gen != _statsLoadGeneration) return;
      if (_isNetworkError(e)) {
        // Keep isStatsLoading = true → shimmer persists; retry with backoff.
        _statsRetryTimer = Timer(_retryDelay(_statsRetryAttempt++), _loadStats);
        return;
      }
      state = state.copyWith(isStatsLoading: false, error: e.toString());
    }
  }

  void _onEvent(HomeEvent event) {
    switch (event) {
      case StatsInvalidated _:
        _loadStats();
      case HomeSessionExpired _:
        _suggestionsRetryTimer?.cancel();
        _statsRetryTimer?.cancel();
        state = HomeState.initial();
      case HomeAuthenticated _:
        state = state.copyWith(isGuest: false);
        _loadInitialData();
      case HomeAppResumed _:
        _loadSuggestions();
        _loadStats();
      case HomeGrpcReconnected _:
        _loadInitialData();
    }
  }

  void onBreathTap() => coordinator.openBreath();
  void onMeditationTap() => coordinator.openMeditation();
  void onComingSoonTap() => coordinator.openComingSoon();
  void onProfileTap() => coordinator.openProfile();
  void onSuggestionTap(String sessionId) => coordinator.openSuggestion(sessionId);
}
