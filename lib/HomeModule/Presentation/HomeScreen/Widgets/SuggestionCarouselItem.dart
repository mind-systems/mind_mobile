import 'package:flutter/material.dart';
import 'package:mind_ui/mind_ui.dart';

class SuggestionCarouselItem extends StatelessWidget {
  final String id;
  final String title;
  final void Function(String id) onTap;

  const SuggestionCarouselItem({
    super.key,
    required this.id,
    required this.title,
    required this.onTap,
  });

  static const double _height = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final width = MediaQuery.of(context).size.width * 0.44;

    return SizedBox(
      width: width,
      height: _height,
      child: InkWell(
        onTap: () => onTap(id),
        borderRadius: BorderRadius.circular(kCardCornerRadius),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(kCardCornerRadius),
            border: Border.all(color: onSurface.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
