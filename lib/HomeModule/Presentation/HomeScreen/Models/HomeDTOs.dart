class SuggestionItemDTO {
  final String id;
  final String title;
  const SuggestionItemDTO({required this.id, required this.title});
}

class StatsDTO {
  final int totalSessions;
  final int durationHours;
  final int durationMinutes;
  final String currentStreak;
  final String longestStreak;
  final String lastSessionDate;
  final double level;
  const StatsDTO({
    required this.totalSessions,
    required this.durationHours,
    required this.durationMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
    required this.level,
  });
}

sealed class HomeEvent {}

class StatsInvalidated extends HomeEvent {}

class HomeSessionExpired extends HomeEvent {}

class HomeAuthenticated extends HomeEvent {}
