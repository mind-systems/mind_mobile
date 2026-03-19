import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/McpModule/Presentation/McpScreen/McpViewModel.dart';
import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenState.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

class McpScreen extends ConsumerWidget {
  static const String path = '/mcp';
  static const String name = 'mcp';

  const McpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mcpViewModelProvider);
    final viewModel = ref.read(mcpViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    ref.listen<McpScreenState>(mcpViewModelProvider, (previous, next) {
      if (previous?.revealToken == null && next.revealToken != null) {
        _showRevealSheet(context, next.revealToken!, next.revealTokenName ?? '', viewModel, l10n);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text(
                      l10n.mcpDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (state.tokens.isNotEmpty) ...[
                    SettingsSection(
                      children: [
                        for (final token in state.tokens)
                          SettingsCell(
                            title: Text(token.name),
                            subtitle: Text(token.createdAtFormatted),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => viewModel.onRevokeTap(token.id),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: viewModel.onCreateTap,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.mcpCreateToken),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  void _showRevealSheet(
    BuildContext context,
    String token,
    String tokenName,
    McpViewModel viewModel,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mcpRevealTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                l10n.mcpRevealWarning,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                token,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        viewModel.onCopyToken();
                        Navigator.of(ctx).pop();
                        viewModel.onRevealDismissed();
                      },
                      child: Text(l10n.mcpCopy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        viewModel.onRevealDismissed();
                      },
                      child: Text(l10n.mcpDone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
