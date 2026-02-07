import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListCellModel.dart';

class BreathSessionListCell extends StatelessWidget {
  final BreathSessionListCellModel model;

  const BreathSessionListCell({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (max 2 lines)
          Text(
            model.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          // Subtitle (1 line)
          Text(
            model.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 12),

          // Separator
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor,
          ),

          const SizedBox(height: 8),

          // Duration
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              model.duration,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
