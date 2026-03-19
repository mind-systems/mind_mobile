import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/McpModule/Presentation/McpScreen/IMcpCoordinator.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

class McpCoordinator implements IMcpCoordinator {
  final BuildContext context;

  McpCoordinator(this.context);

  @override
  void dismiss() {
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Future<String?> showCreateTokenSheet() async {
    if (!context.mounted) return null;
    final l10n = AppLocalizations.of(context)!;
    String name = '';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mcpNewToken, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.mcpTokenName),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.mcpCreateToken),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return null;
    final trimmed = name.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<bool> showRevokeConfirmation() async {
    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final result = await AppAlert.showWithInput(
      context,
      title: l10n.mcpRevokeConfirmTitle,
      description: l10n.mcpRevokeConfirmDescription,
      confirmLabel: l10n.mcpRevokeConfirmTitle,
    );
    return result.confirmed;
  }
}
