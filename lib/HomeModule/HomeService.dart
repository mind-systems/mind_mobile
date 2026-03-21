import 'package:breath_module/breath_module.dart';
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
      durationHours: stats.totalDurationSeconds ~/ 3600,
      durationMinutes: (stats.totalDurationSeconds % 3600) ~/ 60,
      currentStreak: '${stats.currentStreak}',
      longestStreak: '${stats.longestStreak}',
      lastSessionDate: _formatDate(stats.lastSessionDate),
      level: ComplexityIndicator.normalizeComplexity(stats.maxCompletedComplexity.toDouble()),
    );
  }

  @override
  Stream<HomeEvent> observeChanges() {
    final statsInvalidated = liveSessionNotifier.events
        .where((e) => e is LiveBreathSessionEnded)
        .map((_) => StatsInvalidated() as HomeEvent);
    final userChanges = userNotifier.stream.skip(1);
    final sessionExpired = userChanges
        .where((s) => s is GuestState)
        .map((_) => HomeSessionExpired() as HomeEvent);
    final authenticated = userChanges
        .where((s) => s is AuthenticatedState)
        .map((_) => HomeAuthenticated() as HomeEvent);
    return statsInvalidated.mergeWith([sessionExpired, authenticated]);
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
