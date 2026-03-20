class SuggestionItemDTO {
  final String id;
  final String title;
  const SuggestionItemDTO({required this.id, required this.title});
}

class StatsDTO {
  final int totalSessions;
  final String totalDuration;
  final String currentStreak;
  final String longestStreak;
  final String lastSessionDate;
  const StatsDTO({
    required this.totalSessions,
    required this.totalDuration,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
  });
}

sealed class HomeEvent {}

class StatsInvalidated extends HomeEvent {}

class HomeSessionExpired extends HomeEvent {}

class HomeAuthenticated extends HomeEvent {}
