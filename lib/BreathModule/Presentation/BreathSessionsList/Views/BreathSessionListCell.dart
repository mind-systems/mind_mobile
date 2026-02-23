import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';

class BreathSessionListCell extends StatelessWidget {
  final BreathSessionListCellModel model;

  const BreathSessionListCell({
    super.key,
    required this.model,
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

              // Duration + Subtitle
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
                ],
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),

        // Hairline divider (1 physical pixel)
        Container(
          height: pixel,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: theme.dividerColor,
        ),
      ],
    );
  }
}
