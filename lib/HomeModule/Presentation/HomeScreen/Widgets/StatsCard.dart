import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeViewModel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';
import 'package:mind_l10n/mind_l10n.dart';

class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  static String _formatDuration(StatsDTO stats, AppLocalizations l10n) {
    if (stats.durationHours > 0) {
      return l10n.homeStatsDurationHours('${stats.durationHours}', '${stats.durationMinutes}');
    }
    return l10n.homeStatsDurationMinutes('${stats.durationMinutes}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeViewModelProvider).stats;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Text('${l10n.homeStatsTotalSessions}: ${stats.totalSessions}', style: theme.textTheme.bodyMedium),
              Text('${l10n.homeStatsDuration}: ${_formatDuration(stats, l10n)}', style: theme.textTheme.bodyMedium),
              Text('${l10n.homeStatsCurrentStreak}: ${stats.currentStreak}  (${l10n.homeStatsBestStreak}: ${stats.longestStreak})', style: theme.textTheme.bodyMedium),
              Text('${l10n.homeStatsLastSession}: ${stats.lastSessionDate}', style: theme.textTheme.bodyMedium),
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
  }
}
