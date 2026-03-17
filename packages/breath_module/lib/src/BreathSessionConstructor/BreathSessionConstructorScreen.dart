import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'BreathSessionConstructorViewModel.dart';
import 'Models/ActiveFieldKey.dart';
import 'Views/ConstructorFooter.dart';
import 'Views/DescriptionField.dart';
import 'Views/ExerciseEditCell.dart';

class BreathSessionConstructorScreen extends ConsumerStatefulWidget {
  const BreathSessionConstructorScreen({super.key});

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
  final GlobalKey _scrollAreaKey = GlobalKey();

  // ===== Lifecycle =====

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ghostFocus.addListener(_onGhostFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ghostFocus.removeListener(_onGhostFocusChanged);
    _ghostController.dispose();
    _ghostFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
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

  // ===== Ghost TextField logic =====

  void _onGhostFocusChanged() {
    if (!_ghostFocus.hasFocus && _activeField != null) {
      setState(() {
        _activeField = null;
        _activeFieldContext = null;
      });
    }
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
    final exercise = state.exercises.firstWhere((e) => e.id == active.exerciseId);

    final updated = switch (active.fieldName) {
      'inhale' => exercise.copyWith(inhale: value),
      'hold1' => exercise.copyWith(hold1: value),
      'exhale' => exercise.copyWith(exhale: value),
      'hold2' => exercise.copyWith(hold2: value),
      'cycles' => exercise.copyWith(cycles: value),
      'rest' => exercise.copyWith(rest: value),
      _ => exercise,
    };
    vm.updateExercise(active.exerciseId, updated);
  }

  void _dismissGhostField() {
    setState(() => _activeField = null);
    _ghostFocus.unfocus();
  }

  // ===== Actions =====

  Future<void> _saveSession() async {
    final vm = ref.read(breathSessionConstructorProvider.notifier);
    if (!vm.canSave) {
      _showSnackBar(AppLocalizations.of(context)!.breathConstructorValidationError, isError: true);
      return;
    }
    try {
      await vm.save();
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.breathConstructorSavedSuccess);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.breathConstructorSaveError(e.toString()), isError: true);
    }
  }

  Future<void> _deleteSession() async {
    final confirmed = await _showDeleteConfirmation();
    if (confirmed != true) return;
    try {
      await ref.read(breathSessionConstructorProvider.notifier).delete();
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.breathConstructorDeletedSuccess);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.breathConstructorDeleteError(e.toString()), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final l10n = AppLocalizations.of(ctx)!;
        final onSurface = theme.colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.breathConstructorDeleteConfirmTitle, style: TextStyle(color: onSurface)),
          content: Text(l10n.breathConstructorDeleteConfirmDescription, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel, style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete, style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
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
                Expanded(child: _buildExercisesList()),
                ConstructorFooter(onSave: _saveSession, onDelete: _deleteSession),
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

        return Listener(
          onPointerMove: (event) {
            if (_activeField == null) return;
            final box = _scrollAreaKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(event.position);
            if (local.dy >= box.size.height) {
              _dismissGhostField();
            }
          },
          child: GestureDetector(
            key: _scrollAreaKey,
            onTap: _dismissGhostField,
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                DescriptionField(
                  description: state.description,
                  onChanged: (value) => ref
                      .read(breathSessionConstructorProvider.notifier)
                      .updateDescription(value),
                ),
                ...state.exercises.map((exercise) => ExerciseEditCell(
                  key: ValueKey(exercise.id),
                  model: exercise,
                  activeField: _activeField,
                  onFieldTap: (fieldKey, fieldContext) {
                    final value = switch (fieldKey.fieldName) {
                      'inhale' => exercise.inhale,
                      'hold1' => exercise.hold1,
                      'exhale' => exercise.exhale,
                      'hold2' => exercise.hold2,
                      'cycles' => exercise.cycles,
                      'rest' => exercise.rest,
                      _ => 0,
                    };
                    _onFieldTap(fieldKey, value, fieldContext);
                  },
                  onDelete: () => ref.read(breathSessionConstructorProvider.notifier).removeExercise(exercise.id),
                )),
                _buildAddButton(context),
              ],
            ),
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
        onPressed: () => ref.read(breathSessionConstructorProvider.notifier).addExercise(),
        icon: Icon(Icons.add, color: primary),
        label: Text(
          AppLocalizations.of(context)!.breathConstructorAddExercise,
          style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 0),
        ),
      ),
    );
  }
}
