import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';
import '../BreathSessionConstructorViewModel.dart';
import '../Models/BreathSessionConstructorState.dart';
import '../../Widgets/ComplexityIndicator.dart';

class ConstructorFooter extends ConsumerWidget {
  const ConstructorFooter({
    super.key,
    required this.onSave,
    required this.onDelete,
  });

  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      breathSessionConstructorProvider.select(
        (s) => (mode: s.mode, totalDuration: s.totalDuration, complexity: s.complexity),
      ),
    );

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: onSurface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.breathConstructorTotal,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDuration(state.totalDuration),
                style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ComplexityIndicator(complexity: state.complexity, width: 120),
            ],
          ),
          Row(
            children: [
              if (state.mode == ConstructorMode.edit) ...[
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ControlButton(
                    icon: Icons.delete_outline,
                    onPressed: onDelete,
                    destructive: true,
                    iconSize: 28,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              SizedBox(
                width: 50,
                height: 50,
                child: ControlButton(
                  icon: Icons.check,
                  onPressed: onSave,
                  iconSize: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds == 0) return '0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) return '${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m';
    return '${secs}s';
  }
}
