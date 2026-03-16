import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';

final userStatsFutureProvider = FutureProvider.autoDispose<UserStatsDTO>(
  (ref) => App.shared.userApi.fetchStats(),
);

class StatsCard extends ConsumerStatefulWidget {
  const StatsCard({super.key});

  @override
  ConsumerState<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends ConsumerState<StatsCard> {
  late final StreamSubscription<LiveBreathSessionEvent> _eventSub;

  @override
  void initState() {
    super.initState();
    _eventSub = App.shared.liveSessionNotifier.events.listen((event) {
      if (event is LiveBreathSessionEnded) {
        ref.invalidate(userStatsFutureProvider);
      }
    });
  }

  @override
  void dispose() {
    _eventSub.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final parts = iso.split('-');
    const months = ['', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final day = int.parse(parts[2]);
    final month = months[int.parse(parts[1])];
    final year = parts[0];
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userStatsFutureProvider);
    final theme = Theme.of(context);

    return async.when(
      loading: () => SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text('Не удалось загрузить статистику', style: theme.textTheme.bodyMedium),
      ),
      data: (stats) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Text('Всего сессий: ${stats.totalSessions}', style: theme.textTheme.bodyMedium),
                  Text('Время практики: ${_formatDuration(stats.totalDurationSeconds)}', style: theme.textTheme.bodyMedium),
                  Text('Стрик: ${stats.currentStreak} дн.  (рекорд: ${stats.longestStreak} дн.)', style: theme.textTheme.bodyMedium),
                  Text('Последняя сессия: ${_formatDate(stats.lastSessionDate)}', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Container(
              height: 1 / MediaQuery.of(context).devicePixelRatio,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: theme.dividerColor,
            ),
          ],
        );
      },
    );
  }
}
