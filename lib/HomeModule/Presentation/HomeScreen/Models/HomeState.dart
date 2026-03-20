import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';

class HomeState {
  final List<SuggestionItemDTO> suggestions;
  final StatsDTO? stats;
  final bool isGuest;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.suggestions = const [],
    this.stats,
    this.isGuest = true,
    this.isLoading = false,
    this.error,
  });

  factory HomeState.initial() => const HomeState();

  HomeState copyWith({
    List<SuggestionItemDTO>? suggestions,
    StatsDTO? stats,
    bool? isGuest,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      suggestions: suggestions ?? this.suggestions,
      stats: stats ?? this.stats,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
