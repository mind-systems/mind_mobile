import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/TimeOfDayHelper.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind_l10n/mind_l10n.dart';

final suggestionsFutureProvider = FutureProvider.autoDispose<List<SuggestionDTO>>(
  (ref) {
    final period = getDayPeriod(DateTime.now());
    return App.shared.userApi.fetchSuggestions(period.queryValue);
  },
);

class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionsFutureProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(l10n.homeSuggestionsError, style: theme.textTheme.bodyMedium),
      ),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(l10n.homeSuggestionsTitle, style: theme.textTheme.titleSmall),
            ),
            ...suggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final suggestion = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0)
                    Container(
                      height: 1 / MediaQuery.of(context).devicePixelRatio,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: theme.dividerColor,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(suggestion.title, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text(suggestion.description, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
