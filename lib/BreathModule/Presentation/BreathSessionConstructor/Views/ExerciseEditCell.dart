import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';
import 'package:mind/Views/app_dimensions.dart';

class ExerciseEditCell extends StatelessWidget {
  final ExerciseEditCellModel model;
  final ValueChanged<ExerciseEditCellModel> onChanged;
  final VoidCallback onDelete;

  const ExerciseEditCell({
    super.key,
    required this.model,
    required this.onChanged,
    required this.onDelete,
  });

  // ===== Layout constants =====
  static const double _inputFieldWidth = 62.0;
  static const double _inputFieldHeight = 32.0;

  static const double _spaceBetweenPhaseAndControls = 4.0;
  static const double _spaceBetweenControls = 4.0;
  static const double _spaceAfterSeparator = 6.0;

  static const double _footerRowHeight = 24.0;
  static const double _controlRowHeight = 38.0;
  static const double _narrowControlRowHeight = 32.0; // Narrower height for repeat and rest rows

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final textColor = onSurface.withValues(alpha: 0.9);
    final backgroundColor = theme.cardColor.withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kCardCornerRadius),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== PHASES =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPhaseField('Inhale', model.inhale, (v) => onChanged(model.copyWith(inhale: v)), onSurface),
              _buildPhaseField('Hold', model.hold1, (v) => onChanged(model.copyWith(hold1: v)), onSurface),
              _buildPhaseField('Exhale', model.exhale, (v) => onChanged(model.copyWith(exhale: v)), onSurface),
              _buildPhaseField('Hold', model.hold2, (v) => onChanged(model.copyWith(hold2: v)), onSurface),
            ],
          ),

          const SizedBox(height: _spaceBetweenPhaseAndControls),

          // ===== CYCLES =====
          _buildHorizontalField(
            'Repeat',
            model.cycles,
            (v) => onChanged(model.copyWith(cycles: v)),
            onSurface,
            height: _narrowControlRowHeight,
            useNoBorderInput: true,
          ),

          const SizedBox(height: _spaceBetweenControls),

          // ===== SEPARATOR =====
          Container(
            height: 1,
            color: onSurface.withValues(alpha: 0.1),
          ),

          // ===== REST =====
          _buildHorizontalField(
            'Rest',
            model.rest,
            (v) => onChanged(model.copyWith(rest: v)),
            onSurface,
            showIcon: true,
            height: _narrowControlRowHeight,
            useNoBorderInput: true,
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
                    color: textColor,
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
  Widget _buildPhaseField(
      String label, int value, ValueChanged<int> onChanged, Color onSurface) {
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
        _buildNumericInput(value, onChanged, onSurface),
      ],
    );
  }

  // ===== HORIZONTAL FIELD =====
  Widget _buildHorizontalField(
      String label,
      int value,
      ValueChanged<int> onChanged,
      Color onSurface, {
        bool showIcon = false,
        double height = _controlRowHeight,
        useNoBorderInput = true,
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
                _buildNumericInputRightAligned(value, onChanged, onSurface),
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

  Widget _buildNumericInputRightAligned(
      int value,
      ValueChanged<int> onChanged,
      Color onSurface,
      ) {
    final controller = TextEditingController(text: value.toString())
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.toString().length),
      );

    return SizedBox(
      width: _inputFieldWidth,
      height: _inputFieldHeight,
      child: Container(
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.right,
          style: TextStyle(
            color: onSurface,
            fontSize: 16,
            height: 1.1,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (text) {
            if (text.isEmpty) {
              onChanged(0);
              return;
            }
            final parsed = int.tryParse(text);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ),
    );
  }

  Widget _buildNumericInput(int value, ValueChanged<int> onChanged, Color onSurface) {
    final controller = TextEditingController(text: value.toString())
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.toString().length),
      );

    return SizedBox(
      width: _inputFieldWidth,
      height: _inputFieldHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onSurface.withValues(alpha: 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onSurface,
            fontSize: 16,
            height: 1.1,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (text) {
            if (text.isEmpty) {
              onChanged(0);
              return;
            }
            final parsed = int.tryParse(text);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ),
    );
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
