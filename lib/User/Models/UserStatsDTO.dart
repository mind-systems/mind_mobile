class UserStatsDTO {
  final int totalSessions;
  final int totalDurationSeconds;
  final int currentStreak;
  final int longestStreak;
  final String? lastSessionDate;

  UserStatsDTO({
    required this.totalSessions,
    required this.totalDurationSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
  });

  factory UserStatsDTO.fromJson(Map<String, dynamic> json) => UserStatsDTO(
    totalSessions: json['totalSessions'] ?? 0,
    totalDurationSeconds: json['totalDurationSeconds'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    longestStreak: json['longestStreak'] ?? 0,
    lastSessionDate: json['lastSessionDate'] as String?,
  );
}
