import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/l10n/app_localizations.dart';

import 'package:mind/Views/ControlButton.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Views/ExerciseEditCell.dart';

class _DescriptionField extends StatefulWidget {
  const _DescriptionField({required this.description, required this.onChanged});

  final String description;
  final ValueChanged<String> onChanged;

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description)
      ..selection = TextSelection.collapsed(offset: widget.description.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            style: TextStyle(
              color: onSurface,
              fontSize: 16,
              height: 1.2,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран конструктора дыхательных сессий
class BreathSessionConstructorScreen extends ConsumerWidget {
  const BreathSessionConstructorScreen({
    super.key,
  });

  static String name = 'breath_session_constructor';
  static String path = '/$name';

  void _addExercise(WidgetRef ref) {
    ref.read(breathSessionConstructorProvider.notifier).addExercise();
  }

  void _removeExercise(WidgetRef ref, String id) {
    ref.read(breathSessionConstructorProvider.notifier).removeExercise(id);
  }

  Future<void> _deleteSession(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true) return;

    try {
      await ref.read(breathSessionConstructorProvider.notifier).delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.breathConstructorDeletedSuccess),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.breathConstructorDeleteError(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final l10n = AppLocalizations.of(ctx)!;
        final onSurface = theme.colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n.breathConstructorDeleteConfirmTitle,
            style: TextStyle(color: onSurface),
          ),
          content: Text(
            l10n.breathConstructorDeleteConfirmDescription,
            style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSession(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(breathSessionConstructorProvider.notifier);

    if (!vm.canSave) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.breathConstructorValidationError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      await vm.save();

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.breathConstructorSavedSuccess),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.breathConstructorSaveError(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatTotalDuration(int seconds) {
    if (seconds == 0) return '0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) return '${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m';
    return '${secs}s';
  }

  Widget _buildDescriptionField(BuildContext context, WidgetRef ref, String description) {
    return _DescriptionField(
      description: description,
      onChanged: (value) => ref
          .read(breathSessionConstructorProvider.notifier)
          .updateDescription(value),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OutlinedButton.icon(
        onPressed: () => _addExercise(ref),
        icon: Icon(Icons.add, color: primary),
        label: Text(
          AppLocalizations.of(context)!.breathConstructorAddExercise,
          style: TextStyle(
            color: primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: primary,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 0),
        ),
      ),
    );
  }

  Widget _buildExercisesList(
    String description,
    List<dynamic> exercises,
    WidgetRef ref,
  ) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.scrollDelta != null &&
            notification.scrollDelta! < 0) {
          FocusScope.of(notification.context!).unfocus();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: exercises.length + 2, // description + exercises + add button
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildDescriptionField(context, ref, description);
          }

          if (index <= exercises.length) {
            final exercise = exercises[index - 1];
            return ExerciseEditCell(
              key: ValueKey(exercise.id),
              model: exercise,
              onChanged: (updated) => ref
                  .read(breathSessionConstructorProvider.notifier)
                  .updateExercise(exercise.id, updated),
              onDelete: () => _removeExercise(ref, exercise.id),
            );
          }

          return _buildAddButton(context, ref);
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, ConstructorMode mode, int totalDuration) {
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
                _formatTotalDuration(totalDuration),
                style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (mode == ConstructorMode.edit) ...[
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ControlButton(
                    icon: Icons.delete_outline,
                    onPressed: () => _deleteSession(context, ref),
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
                  onPressed: () => _saveSession(context, ref),
                  iconSize: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breathSessionConstructorProvider);
    final description = state.description;
    final exercises = state.exercises;
    final totalDuration = state.totalDuration;
    final mode = state.mode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _buildExercisesList(description, exercises, ref),
            ),
            _buildFooter(context, ref, mode, totalDuration),
          ],
        ),
      ),
    );
  }
}
