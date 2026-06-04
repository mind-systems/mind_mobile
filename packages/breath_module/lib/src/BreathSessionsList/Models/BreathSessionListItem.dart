sealed class BreathSessionListItem {}

/// Section grouping for the list (server-provided)
enum ListSection {
  /// Starred sessions (may duplicate entries from mine/shared)
  starred,
  /// Sessions created by the current user
  mine,
  /// Public sessions from other users
  shared,
}

/// Cell model with session data
class BreathSessionListCellModel extends BreathSessionListItem {
  final String id;
  /// Session description (1–2 lines)
  final String title;
  /// Breathing pattern string: "● 4-4-4-4   ■ 6-6   ▲ 4-2-6"
  final String subtitle;
  /// Total session duration: "12:40"
  final String duration;
  /// Session complexity (0–500+)
  final double complexity;
  /// Ownership type (used for metadata display)
  final SessionOwnership ownership;
  /// Whether the session is starred
  final bool isStarred;
  /// Server-provided section this cell belongs to
  final ListSection section;

  BreathSessionListCellModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.complexity,
    required this.ownership,
    required this.isStarred,
    required this.section,
  });
}

/// Section header type
enum SectionHeaderType {
  mySessions,
  starredSessions,
  sharedSessions,
}

/// Section header (group separator)
class SectionHeaderModel extends BreathSessionListItem {
  final SectionHeaderType type;
  SectionHeaderModel(this.type);
}

/// Skeleton cell (for initial/empty/paging states)
class SkeletonCellModel extends BreathSessionListItem {
  final bool animated;
  SkeletonCellModel({required this.animated});
}

/// Session ownership type
enum SessionOwnership {
  /// Session created by the current user
  mine,
  /// Public session from another user
  shared,
}
