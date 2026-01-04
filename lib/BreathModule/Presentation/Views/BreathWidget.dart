import 'package:flutter/widgets.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapePainter.dart';

class BreathShapeWidget extends StatelessWidget {
  final SetShape shape;
  final TriangleOrientation? triangleOrientation;
  final BreathMotionEngine controller;

  final Color? shapeColor;
  final Color? pointColor;
  final double? strokeWidth;
  final double? pointRadius;

  const BreathShapeWidget({
    super.key,
    required this.shape,
    required this.controller,
    this.triangleOrientation,
    this.shapeColor,
    this.pointColor,
    this.strokeWidth,
    this.pointRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BreathShapePainter(
            shape: shape,
            normalizedTime: controller.normalizedPosition,
            triangleOrientation: triangleOrientation,
            shapeColor: shapeColor ?? const Color(0xFF00D9FF),
            pointColor: pointColor ?? const Color(0xFFFFFFFF),
            shapeStrokeWidth: strokeWidth ?? 3.0,
            pointRadius: pointRadius ?? 8.0,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
