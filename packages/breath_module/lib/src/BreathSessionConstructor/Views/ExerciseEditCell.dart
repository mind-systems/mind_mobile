import 'package:flutter/material.dart';
import 'package:mind_ui/mind_ui.dart';
import 'package:mind_l10n/mind_l10n.dart';
import '../Models/ActiveFieldKey.dart';
import '../Models/ExerciseEditCellModel.dart';
import 'BlinkingCursor.dart';

class ExerciseEditCell extends StatelessWidget {
  final ExerciseEditCellModel model;
  final VoidCallback onDelete;
  final ActiveFieldKey? activeField;
  final void Function(ActiveFieldKey key, BuildContext fieldContext) onFieldTap;

  const ExerciseEditCell({
    super.key,
    required this.model,
    required this.onDelete,
    required this.activeField,
    required this.onFieldTap,
  });

  // ===== Layout constants =====
  static const double _inputFieldWidth = 62.0;
  static const double _inputFieldHeight = 32.0;

  static const double _spaceBetweenPhaseAndControls = 4.0;
  static const double _spaceBetweenControls = 4.0;
  static const double _spaceAfterSeparator = 6.0;

  static const double _footerRowHeight = 24.0;
  static const double _narrowControlRowHeight = 32.0;

  bool _isActive(String fieldName) =>
      activeField != null &&
      activeField!.exerciseId == model.id &&
      activeField!.fieldName == fieldName;

  void _tap(String fieldName, int value, BuildContext fieldContext) {
    onFieldTap(ActiveFieldKey(exerciseId: model.id, fieldName: fieldName), fieldContext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final backgroundColor = theme.cardColor.withValues(alpha: 0.8);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kCardCornerRadius),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== PHASES =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPhaseField(l10n.breathPhaseInhale, 'inhale', model.inhale, onSurface),
              _buildPhaseField(l10n.breathPhaseHold, 'hold1', model.hold1, onSurface),
              _buildPhaseField(l10n.breathPhaseExhale, 'exhale', model.exhale, onSurface),
              _buildPhaseField(l10n.breathPhaseHold, 'hold2', model.hold2, onSurface),
            ],
          ),

          const SizedBox(height: _spaceBetweenPhaseAndControls),

          // ===== CYCLES =====
          _buildHorizontalField(
            l10n.breathConstructorRepeat,
            'cycles',
            model.cycles,
            onSurface,
            height: _narrowControlRowHeight,
            useNoBorder: true,
          ),

          const SizedBox(height: _spaceBetweenControls),

          // ===== SEPARATOR =====
          Container(
            height: 1,
            color: onSurface.withValues(alpha: 0.1),
          ),

          // ===== REST =====
          _buildHorizontalField(
            l10n.breathPhaseRest,
            'rest',
            model.rest,
            onSurface,
            showIcon: true,
            height: _narrowControlRowHeight,
            useNoBorder: true,
          ),

          // ===== SEPARATOR =====
          Container(
            height: 1,
            color: onSurface.withValues(alpha: 0.1),
          ),

          const SizedBox(height: _spaceAfterSeparator),

          // ===== FOOTER =====
          SizedBox(
            height: _footerRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _formatDuration(model.totalDuration),
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (model.icon != null) _buildShapeIcon(model.icon!, onSurface),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: onSurface.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== PHASE FIELD =====
  Widget _buildPhaseField(String label, String fieldName, int value, Color onSurface) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        _buildNumericDisplay(
          fieldName: fieldName,
          value: value,
          onSurface: onSurface,
          textAlign: TextAlign.center,
          showBorder: true,
        ),
      ],
    );
  }

  // ===== HORIZONTAL FIELD =====
  Widget _buildHorizontalField(
    String label,
    String fieldName,
    int value,
    Color onSurface, {
    bool showIcon = false,
    double height = 38.0,
    bool useNoBorder = false,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Center(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNumericDisplay(
                  fieldName: fieldName,
                  value: value,
                  onSurface: onSurface,
                  textAlign: TextAlign.right,
                  showBorder: false,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: showIcon
                      ? Icon(
                          Icons.access_time,
                          size: 16,
                          color: onSurface.withValues(alpha: 0.5),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== NUMERIC DISPLAY (replaces TextField) =====
  Widget _buildNumericDisplay({
    required String fieldName,
    required int value,
    required Color onSurface,
    required TextAlign textAlign,
    required bool showBorder,
  }) {
    final isFieldActive = _isActive(fieldName);
    final displayText = value == 0 ? '0' : value.toString();

    return Builder(builder: (fieldContext) => GestureDetector(
      onTap: () => _tap(fieldName, value, fieldContext),
      child: SizedBox(
        width: _inputFieldWidth,
        height: _inputFieldHeight,
        child: Container(
          decoration: showBorder
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isFieldActive
                        ? onSurface.withValues(alpha: 0.4)
                        : onSurface.withValues(alpha: 0.1),
                  ),
                )
              : null,
          alignment: textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayText,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              BlinkingCursor(color: onSurface, active: isFieldActive),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildShapeIcon(ExerciseIcon icon, Color onSurface) {
    IconData iconData;

    switch (icon) {
      case ExerciseIcon.circle:
        iconData = Icons.panorama_fish_eye;
        break;
      case ExerciseIcon.triangleUp:
      case ExerciseIcon.triangleDown:
        iconData = Icons.change_history;
        break;
      case ExerciseIcon.square:
        iconData = Icons.crop_square;
        break;
      case ExerciseIcon.rest:
        iconData = Icons.self_improvement;
        break;
    }

    return Icon(
      iconData,
      size: 20,
      color: onSurface.withValues(alpha: 0.6),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) return '${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m';
    return '${secs}s';
  }
}
