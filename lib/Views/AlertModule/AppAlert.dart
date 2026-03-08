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
    String? title,
    String? description,
    String? inputHint,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) async {
    String inputText = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: title != null
              ? Text(title, style: TextStyle(color: theme.colorScheme.onSurface))
              : null,
          contentPadding: title == null
              ? const EdgeInsets.fromLTRB(24, 24, 24, 24)
              : const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description != null)
                Padding(
                  padding: EdgeInsets.only(bottom: inputHint != null ? 16 : 0),
                  child: Text(
                    description,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              if (inputHint != null)
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
                cancelLabel,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
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
