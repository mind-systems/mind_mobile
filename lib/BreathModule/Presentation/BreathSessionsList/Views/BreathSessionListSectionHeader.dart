import 'package:flutter/material.dart';

class BreathSessionListSectionHeader extends StatelessWidget {
  final String title;

  const BreathSessionListSectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
