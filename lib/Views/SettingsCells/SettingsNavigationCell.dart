import 'package:flutter/material.dart';
import 'package:mind/Views/SettingsCells/SettingsCell.dart';

class SettingsNavigationCell extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const SettingsNavigationCell({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SettingsCell(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 20, color: onSurface.withValues(alpha: 0.5)),
        ],
      ),
      onTap: onTap,
    );
  }
}
