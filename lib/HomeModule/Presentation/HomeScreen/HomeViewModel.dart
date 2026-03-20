import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  HomeState build() {
    final subscription = service.observeChanges().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());

    Future.microtask(() => _loadInitialData());

    return HomeState.initial().copyWith(isGuest: service.isGuest);
  }

  void _loadInitialData() {
    _loadSuggestions();
    _loadStats();
  }

  Future<void> _loadSuggestions() async {
    state = state.copyWith(isLoading: true);
    try {
      final suggestions = await service.fetchSuggestions();
      state = state.copyWith(suggestions: suggestions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await service.fetchStats();
      if (stats != null) {
        state = state.copyWith(stats: stats);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _onEvent(HomeEvent event) {
    switch (event) {
      case StatsInvalidated _:
        _loadStats();
      case HomeSessionExpired _:
        state = HomeState.initial();
      case HomeAuthenticated _:
        state = state.copyWith(isGuest: false);
        _loadInitialData();
    }
  }

  void onBreathTap() => coordinator.openBreath();
  void onComingSoonTap() => coordinator.openComingSoon();
  void onProfileTap() => coordinator.openProfile();
  void onSuggestionTap(String sessionId) => coordinator.openSuggestion(sessionId);
}
