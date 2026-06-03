import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeViewModel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:shimmer/shimmer.dart';

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
    final state = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!state.isGuest && state.isStatsLoading) {
      return const _StatsShimmer();
    }

    if (state.stats == null) return const SizedBox.shrink();

    final stats = state.stats!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Text('${l10n.level}: ${stats.level.toStringAsFixed(1)}', style: theme.textTheme.bodyMedium),
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

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.cardColor;
    final highlight = theme.highlightColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _shimmerLine(base, width: 160),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 200),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 180),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 220),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 140),
                const SizedBox(height: 14),
              ],
            ),
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

  Widget _shimmerLine(Color color, {required double width}) {
    return Container(
      height: 14,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}
