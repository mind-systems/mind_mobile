import 'package:breath_module/breath_module.dart' show BreathSessionScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/TimeOfDayHelper.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/AutoScrollCarousel.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionCarouselItem.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsTitle.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

final suggestionsFutureProvider = FutureProvider.autoDispose<List<SuggestionDTO>>(
  (ref) {
    final period = getDayPeriod(DateTime.now());
    return App.shared.userApi.fetchSuggestions(period.queryValue);
  },
);

class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({super.key});

  static const double _carouselHeight = 88.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionsFutureProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
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
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return SuggestionCarouselItem(
                      id: suggestion.id,
                      title: suggestion.title,
                      onTap: (id) => context.push(
                        BreathSessionScreen.path,
                        extra: id,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
