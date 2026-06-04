import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionListEntry {
  final BreathSession session;
  final BreathListSection section;

  const BreathSessionListEntry({
    required this.session,
    required this.section,
  });
}

class BreathSessionsListResponse {
  final List<BreathSessionListEntry> entries;
  final String? nextCursor;

  const BreathSessionsListResponse({
    required this.entries,
    required this.nextCursor,
  });

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
