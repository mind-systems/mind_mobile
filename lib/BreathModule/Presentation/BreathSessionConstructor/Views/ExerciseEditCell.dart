import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';

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

  static const double _spaceBetweenPhaseAndControls = 12.0;
  static const double _spaceBetweenControls = 4.0;
  static const double _spaceBetweenControlsAndFooter = 8.0;
  static const double _spaceAfterSeparator = 6.0;

  static const double _footerRowHeight = 24.0;
  static const double _controlRowHeight = 38.0;

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white.withValues(alpha: 0.9);
    final backgroundColor = const Color(0xFF1A2433).withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
              _buildPhaseField('Inhale', model.inhale, (v) => onChanged(model.copyWith(inhale: v))),
              _buildPhaseField('Hold', model.hold1, (v) => onChanged(model.copyWith(hold1: v))),
              _buildPhaseField('Exhale', model.exhale, (v) => onChanged(model.copyWith(exhale: v))),
              _buildPhaseField('Hold', model.hold2, (v) => onChanged(model.copyWith(hold2: v))),
            ],
          ),

          const SizedBox(height: _spaceBetweenPhaseAndControls),

          // ===== CYCLES =====
          _buildHorizontalField(
            'Repeat',
            model.cycles,
                (v) => onChanged(model.copyWith(cycles: v)),
          ),

          const SizedBox(height: _spaceBetweenControls),

          // ===== REST =====
          _buildHorizontalField(
            'Rest',
            model.rest,
                (v) => onChanged(model.copyWith(rest: v)),
            showIcon: true,
          ),

          const SizedBox(height: _spaceBetweenControlsAndFooter),

          // ===== SEPARATOR =====
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
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
                if (model.shape != null) _buildShapeIcon(model.shape!),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.white.withValues(alpha: 0.5),
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
      String label, int value, ValueChanged<int> onChanged) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        _buildNumericInput(value, onChanged),
      ],
    );
  }

  // ===== HORIZONTAL FIELD =====
  Widget _buildHorizontalField(
      String label,
      int value,
      ValueChanged<int> onChanged, {
        bool showIcon = false,
      }) {
    return SizedBox(
      height: _controlRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (showIcon) ...[
            Icon(
              Icons.access_time,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
          ],
          Center(
            child: _buildNumericInput(value, onChanged),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericInput(int value, ValueChanged<int> onChanged) {
    final controller = TextEditingController(text: value.toString())
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.toString().length),
      );

    return SizedBox(
      width: _inputFieldWidth,
      height: _inputFieldHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
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

  Widget _buildShapeIcon(SetShape shape) {
    IconData iconData;

    switch (shape) {
      case SetShape.circle:
        iconData = Icons.panorama_fish_eye;
        break;
      case SetShape.triangleUp:
      case SetShape.triangleDown:
        iconData = Icons.change_history;
        break;
      case SetShape.square:
        iconData = Icons.crop_square;
        break;
    }

    return Icon(
      iconData,
      size: 20,
      color: Colors.white.withValues(alpha: 0.6),
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
