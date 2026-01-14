import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/Views/ControlButton.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Views/ExerciseEditCell.dart';

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
        const SnackBar(
          content: Text('Session deleted'),
          backgroundColor: Color(0xFF00D9FF),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting session: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2433),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete session?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFD90000)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSession(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(breathSessionConstructorProvider.notifier);

    if (!vm.canSave) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure at least one valid exercise'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await vm.save();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session saved'),
          backgroundColor: Color(0xFF00D9FF),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving session: $e'),
          backgroundColor: Colors.redAccent,
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

  Widget _buildDescriptionField(WidgetRef ref, String description) {
    final controller = TextEditingController(text: description)
      ..selection = TextSelection.collapsed(offset: description.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2433).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            onChanged: (value) => ref
                .read(breathSessionConstructorProvider.notifier)
                .updateDescription(value),
            style: const TextStyle(
              color: Colors.white,
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

  Widget _buildAddButton(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OutlinedButton.icon(
        onPressed: () => _addExercise(ref),
        icon: const Icon(Icons.add, color: Color(0xFF00D9FF)),
        label: const Text(
          'Add exercise',
          style: TextStyle(
            color: Color(0xFF00D9FF),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(
            color: Color(0xFF00D9FF),
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
            return _buildDescriptionField(ref, description);
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

          return _buildAddButton(ref);
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, ConstructorMode mode, int totalDuration) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2433).withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
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
                'Total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTotalDuration(totalDuration),
                style: const TextStyle(
                  color: Colors.white,
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
      backgroundColor: const Color(0xFF0A0E27),
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
