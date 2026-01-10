import 'package:flutter/widgets.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapePainter.dart';

class BreathShapeWidget extends StatelessWidget {
  final BreathMotionEngine motionController;
  final BreathShapeShifter shapeController;

  final Color? shapeColor;
  final Color? pointColor;
  final double? strokeWidth;
  final double? pointRadius;

  const BreathShapeWidget({
    super.key,
    required this.motionController,
    required this.shapeController,
    this.shapeColor,
    this.pointColor,
    this.strokeWidth,
    this.pointRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([motionController, shapeController]),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Обновляем размеры shapeShifter при изменении размера виджета
            final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
            final size = constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              shapeController.updateBounds(center, size);
            });

            return CustomPaint(
              painter: BreathShapePainter(
                shapeShifter: shapeController,
                normalizedTime: motionController.normalizedPosition,
                shapeColor: shapeColor ?? const Color(0xFF00D9FF),
                pointColor: pointColor ?? const Color(0xFFFFFFFF),
                shapeStrokeWidth: strokeWidth ?? 3.0,
                pointRadius: pointRadius ?? 8.0,
              ),
              child: const SizedBox.expand(),
            );
          },
        );
      },
    );
  }
}
