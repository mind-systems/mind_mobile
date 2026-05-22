import 'package:flutter/material.dart';
import 'package:mind_l10n/mind_l10n.dart';

/// Shows a confirmation dialog asking the user whether to disconnect the BCI
/// device. Returns `true` if the user confirms, `false` if they cancel or
/// dismiss the dialog by tapping the barrier.
Future<bool> showBciDisconnectDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.bciPairingDisconnectConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: Text(l10n.bciPairingDisconnect),
        ),
      ],
    ),
  );
  return result ?? false;
}
