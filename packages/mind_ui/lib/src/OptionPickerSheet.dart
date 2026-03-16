import 'package:flutter/material.dart';

class OptionPickerDialog extends StatelessWidget {
  final String title;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const OptionPickerDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final divider = Divider(
      height: hairline,
      thickness: hairline,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
    );
    return AlertDialog(
      backgroundColor: theme.cardColor,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          divider,
          for (int index = 0; index < options.length; index++) ...[
            if (index > 0) divider,
            InkWell(
              onTap: () {
                onSelect(index);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                child: Center(
                  child: Text(
                    options[index],
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: index == selectedIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showOptionPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  required int selectedIndex,
  required ValueChanged<int> onSelect,
}) {
  showDialog(
    context: context,
    builder: (_) => OptionPickerDialog(
      title: title,
      options: options,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
    ),
  );
}
