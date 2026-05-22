import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';

class HomeState {
  final List<SuggestionItemDTO> suggestions;
  final StatsDTO? stats;
  final bool isGuest;
  final bool isSuggestionsLoading;
  final bool isStatsLoading;
  final String? error;

  const HomeState({
    this.suggestions = const [],
    this.stats,
    this.isGuest = true,
    this.isSuggestionsLoading = false,
    this.isStatsLoading = false,
    this.error,
  });

  factory HomeState.initial() => const HomeState();

  HomeState copyWith({
    List<SuggestionItemDTO>? suggestions,
    StatsDTO? stats,
    bool? isGuest,
    bool? isSuggestionsLoading,
    bool? isStatsLoading,
    String? error,
  }) => HomeState(
    suggestions: suggestions ?? this.suggestions,
    stats: stats ?? this.stats,
    isGuest: isGuest ?? this.isGuest,
    isSuggestionsLoading: isSuggestionsLoading ?? this.isSuggestionsLoading,
    isStatsLoading: isStatsLoading ?? this.isStatsLoading,
    error: error ?? this.error,
  );
}
