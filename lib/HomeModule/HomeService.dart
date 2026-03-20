import 'package:rxdart/rxdart.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionNotifier.dart';
import 'package:mind/Core/TimeOfDayHelper.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/IHomeService.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';
import 'package:mind/User/IUserApi.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';

class HomeService implements IHomeService {
  final IUserApi userApi;
  final LiveBreathSessionNotifier liveSessionNotifier;
  final UserNotifier userNotifier;

  HomeService({
    required this.userApi,
    required this.liveSessionNotifier,
    required this.userNotifier,
  });

  @override
  bool get isGuest => userNotifier.currentState is GuestState;

  @override
  Future<List<SuggestionItemDTO>> fetchSuggestions() async {
    if (isGuest) return [];
    final period = getDayPeriod(DateTime.now());
    final suggestions = await userApi.fetchSuggestions(period.queryValue);
    return suggestions.map((s) => SuggestionItemDTO(id: s.id, title: s.title)).toList();
  }

  @override
  Future<StatsDTO?> fetchStats() async {
    if (isGuest) return null;
    final stats = await userApi.fetchStats();
    return StatsDTO(
      totalSessions: stats.totalSessions,
      totalDuration: _formatDuration(stats.totalDurationSeconds),
      currentStreak: '${stats.currentStreak}',
      longestStreak: '${stats.longestStreak}',
      lastSessionDate: _formatDate(stats.lastSessionDate),
    );
  }

  @override
  Stream<HomeEvent> observeChanges() {
    final statsInvalidated = liveSessionNotifier.events
        .where((e) => e is LiveBreathSessionEnded)
        .map((_) => StatsInvalidated() as HomeEvent);
    final sessionExpired = userNotifier.stream
        .where((s) => s is GuestState)
        .map((_) => HomeSessionExpired() as HomeEvent);
    final authenticated = userNotifier.stream
        .where((s) => s is AuthenticatedState)
        .map((_) => HomeAuthenticated() as HomeEvent);
    return statsInvalidated.mergeWith([sessionExpired, authenticated]);
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h h $m min';
    return '$m min';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse(iso);
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }
}
