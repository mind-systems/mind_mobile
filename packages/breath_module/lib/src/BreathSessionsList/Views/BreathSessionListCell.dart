import 'package:flutter/material.dart';
import '../Models/BreathSessionListItem.dart';
import '../../Widgets/ComplexityIndicator.dart';

class BreathSessionListCell extends StatelessWidget {
  final BreathSessionListCellModel model;
  final bool showDivider;

  const BreathSessionListCell({
    super.key,
    required this.model,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixel = 1 / MediaQuery.of(context).devicePixelRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),

              // Title
              Text(
                model.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),

              const SizedBox(height: 6),

              // Duration + Subtitle + Complexity
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    model.duration,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ComplexityIndicator(complexity: model.complexity),
                ],
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),

        // Hairline divider (1 physical pixel)
        if (showDivider)
          Container(
            height: pixel,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: theme.dividerColor,
          ),
      ],
    );
  }
}
