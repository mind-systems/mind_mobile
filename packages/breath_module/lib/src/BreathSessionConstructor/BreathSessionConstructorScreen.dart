import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';
import 'BreathSessionConstructorViewModel.dart';
import 'Models/BreathSessionConstructorState.dart';
import 'Views/ExerciseEditCell.dart';
import '../Widgets/ComplexityIndicator.dart';

class ActiveFieldKey {
  final String exerciseId;
  final String fieldName;

  const ActiveFieldKey({required this.exerciseId, required this.fieldName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveFieldKey &&
          exerciseId == other.exerciseId &&
          fieldName == other.fieldName;

  @override
  int get hashCode => Object.hash(exerciseId, fieldName);
}

class _DescriptionField extends StatefulWidget {
  const _DescriptionField({required this.description, required this.onChanged});

  final String description;
  final ValueChanged<String> onChanged;

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description)
      ..selection = TextSelection.collapsed(offset: widget.description.length);
}

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
            focusNode: _focusNode,
            textInputAction: TextInputAction.next,
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
class BreathSessionConstructorScreen extends ConsumerStatefulWidget {
  const BreathSessionConstructorScreen({
    super.key,
  });

  static String name = 'breath_session_constructor';
  static String path = '/$name';

  @override
  ConsumerState<BreathSessionConstructorScreen> createState() =>
      _BreathSessionConstructorScreenState();
}

class _BreathSessionConstructorScreenState
    extends ConsumerState<BreathSessionConstructorScreen>
    with WidgetsBindingObserver {
  ActiveFieldKey? _activeField;
  BuildContext? _activeFieldContext;
  final TextEditingController _ghostController = TextEditingController();
  final FocusNode _ghostFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ghostFocus.addListener(_onGhostFocusChanged);
  }

  @override
  void didChangeMetrics() {
    // Keyboard appeared or resized — scroll active field into view
    final ctx = _activeFieldContext;
    if (ctx == null || _activeField == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activeFieldContext != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.8,
        );
      }
    });
  }

  void _onGhostFocusChanged() {
    if (!_ghostFocus.hasFocus && _activeField != null) {
      setState(() {
        _activeField = null;
        _activeFieldContext = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ghostFocus.removeListener(_onGhostFocusChanged);
    _ghostController.dispose();
    _ghostFocus.dispose();
    super.dispose();
  }

  void _onFieldTap(ActiveFieldKey key, int currentValue, BuildContext fieldContext) {
    setState(() {
      _activeField = key;
      _activeFieldContext = fieldContext;
    });
    _ghostController.text = currentValue == 0 ? '' : currentValue.toString();
    _ghostController.selection = TextSelection.collapsed(
      offset: _ghostController.text.length,
    );
    _ghostFocus.requestFocus();
  }

  void _onGhostTextChanged(String text) {
    final active = _activeField;
    if (active == null) return;

    final value = text.isEmpty ? 0 : (int.tryParse(text) ?? 0);
    final vm = ref.read(breathSessionConstructorProvider.notifier);
    final state = ref.read(breathSessionConstructorProvider);
    final exercise = state.exercises.firstWhere(
      (e) => e.id == active.exerciseId,
      orElse: () => throw StateError('Exercise not found'),
    );

    switch (active.fieldName) {
      case 'inhale':
        vm.updateExercise(active.exerciseId, exercise.copyWith(inhale: value));
      case 'hold1':
        vm.updateExercise(active.exerciseId, exercise.copyWith(hold1: value));
      case 'exhale':
        vm.updateExercise(active.exerciseId, exercise.copyWith(exhale: value));
      case 'hold2':
        vm.updateExercise(active.exerciseId, exercise.copyWith(hold2: value));
      case 'cycles':
        vm.updateExercise(active.exerciseId, exercise.copyWith(cycles: value));
      case 'rest':
        vm.updateExercise(active.exerciseId, exercise.copyWith(rest: value));
    }
  }

  void _dismissGhostField() {
    setState(() => _activeField = null);
    _ghostFocus.unfocus();
  }

  void _addExercise() {
    ref.read(breathSessionConstructorProvider.notifier).addExercise();
  }

  void _removeExercise(String id) {
    ref.read(breathSessionConstructorProvider.notifier).removeExercise(id);
  }

  Future<void> _deleteSession() async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true) return;

    try {
      await ref.read(breathSessionConstructorProvider.notifier).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.breathConstructorDeletedSuccess),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

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

  Future<void> _saveSession() async {
    final vm = ref.read(breathSessionConstructorProvider.notifier);

    if (!vm.canSave) {
      if (!mounted) return;
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

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.breathConstructorSavedSuccess),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Ghost TextField — invisible, always holds focus for numeric input
            Positioned(
              left: -1000,
              top: -1000,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: _ghostController,
                  focusNode: _ghostFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onGhostTextChanged,
                  onSubmitted: (_) => _dismissGhostField(),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _buildExercisesList(),
                ),
                _buildFooter(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesList() {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(
          breathSessionConstructorProvider.select(
            (s) => (description: s.description, exercises: s.exercises),
          ),
        );

        return GestureDetector(
          onTap: _dismissGhostField,
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _DescriptionField(
                  description: state.description,
                  onChanged: (value) => ref
                      .read(breathSessionConstructorProvider.notifier)
                      .updateDescription(value),
                ),
                ...state.exercises.map((exercise) => ExerciseEditCell(
                  key: ValueKey(exercise.id),
                  model: exercise,
                  activeField: _activeField,
                  onFieldTap: (key, fieldContext) {
                    final value = switch (key.fieldName) {
                      'inhale' => exercise.inhale,
                      'hold1' => exercise.hold1,
                      'exhale' => exercise.exhale,
                      'hold2' => exercise.hold2,
                      'cycles' => exercise.cycles,
                      'rest' => exercise.rest,
                      _ => 0,
                    };
                    _onFieldTap(key, value, fieldContext);
                  },
                  onDelete: () => _removeExercise(exercise.id),
                )),
                _buildAddButton(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OutlinedButton.icon(
        onPressed: _addExercise,
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

  Widget _buildFooter() {
    return Consumer(
      builder: (context, ref, _) {
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
                    _formatTotalDuration(state.totalDuration),
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
                        onPressed: _deleteSession,
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
                      onPressed: _saveSession,
                      iconSize: 28,
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
