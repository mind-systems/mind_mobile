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
    final baseStyle = theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary);

    final Widget textWidget;
    if (title.startsWith('★')) {
      textWidget = Text.rich(TextSpan(children: [
        TextSpan(text: '★', style: baseStyle?.copyWith(color: theme.colorScheme.tertiary)),
        TextSpan(text: title.substring(1), style: baseStyle),
      ]));
    } else {
      textWidget = Text(title, style: baseStyle);
    }

    return ColoredBox(
      color: theme.cardColor.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: textWidget,
      ),
    );
  }
}
