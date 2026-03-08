import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final List<Widget> children;

  const SettingsSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final divider = Divider(
      height: hairline,
      thickness: hairline,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
    );
    final divided = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) divided.add(divider);
      divided.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: divided),
      ),
    );
  }
}
