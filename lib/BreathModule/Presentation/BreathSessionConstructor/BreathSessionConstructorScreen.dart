import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Views/ExerciseEditCell.dart';

/// Экран конструктора дыхательных сессий
class BreathSessionConstructorScreen extends ConsumerWidget {
  const BreathSessionConstructorScreen({
    super.key,
    this.initialSession,
  });

  final BreathSession? initialSession;

  static String name = 'breath_session_constructor';
  static String path = '/$name';

  void _addExercise(WidgetRef ref) {
    ref.read(breathSessionConstructorProvider.notifier).addExercise();
  }

  void _removeExercise(WidgetRef ref, String id) {
    ref.read(breathSessionConstructorProvider.notifier).removeExercise(id);
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

    // Диалог для ввода имени сессии
    final name = await _showNameDialog(context);
    if (name == null) return;

    // Сборка сессии
    final session = vm.buildSession(tickSource: TickSource.timer);

    // TODO: Сохранение в репозиторий (SharedPreferences / SQLite)
    // await ref.read(sessionRepositoryProvider).saveSession(name, session);

    if (!context.mounted) return;

    // Показываем подтверждение
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session "$name" saved!'),
        backgroundColor: const Color(0xFF00D9FF),
      ),
    );

    // TODO: Навигация на экран сессии или закрытие
    Navigator.pop(context);
  }

  Future<String?> _showNameDialog(BuildContext context) async {
    final controller = TextEditingController();
    final now = DateTime.now();
    final defaultName = 'Practice ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    controller.text = defaultName;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2433),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Name your session',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter session name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(context, name.isEmpty ? defaultName : name);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF00D9FF)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotalDuration(int seconds) {
    if (seconds == 0) return '0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) return '${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m';
    return '${secs}s';
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

  Widget _buildExercisesList(List<dynamic> exercises, WidgetRef ref) {
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
        itemCount: exercises.length + 1,
        itemBuilder: (context, index) {
          if (index < exercises.length) {
            final exercise = exercises[index];
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

  Widget _buildFooter(BuildContext context, WidgetRef ref, int totalDuration) {
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
                'Total duration',
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
          ElevatedButton(
            onPressed: () => _saveSession(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: const Color(0xFF0A0E27),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breathSessionConstructorProvider);
    final exercises = state.exercises;
    final totalDuration = state.totalDuration;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _buildExercisesList(exercises, ref),
            ),
            _buildFooter(context, ref, totalDuration),
          ],
        ),
      ),
    );
  }
}
