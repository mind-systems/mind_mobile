import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/TimeOfDayHelper.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/HomeViewModel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/AutoScrollCarousel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionCarouselItem.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsTitle.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({super.key});

  static const double _carouselHeight = 88.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final vm = ref.read(homeViewModelProvider.notifier);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.suggestions.isEmpty) return const SizedBox.shrink();

    final title = getSuggestionsTitle(getDayPeriod(DateTime.now()), l10n);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardCornerRadius),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(title, style: theme.textTheme.titleSmall),
          ),
          SizedBox(
            height: _carouselHeight,
            child: AutoScrollCarousel(
              itemCount: state.suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = state.suggestions[index];
                return SuggestionCarouselItem(
                  id: suggestion.id,
                  title: suggestion.title,
                  onTap: (id) => vm.onSuggestionTap(id),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
