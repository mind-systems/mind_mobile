import 'package:flutter/material.dart';
import 'package:mind/Views/AlertModule/Models/AlertResult.dart';

abstract class AppAlert {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
          content: description != null
              ? Text(description, style: TextStyle(color: theme.colorScheme.onSurface))
              : null,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  static Future<AlertResult> showWithInput(
    BuildContext context, {
    required String title,
    String? description,
    String? inputHint,
  }) async {
    String inputText = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    description,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              TextField(
                onChanged: (value) => inputText = value,
                decoration: InputDecoration(hintText: inputHint),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return AlertResult(
      confirmed: confirmed ?? false,
      text: (confirmed ?? false) ? inputText : null,
    );
  }
}
