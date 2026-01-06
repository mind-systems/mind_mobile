import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathShapeShifter.dart';

/// CustomPainter для отрисовки дыхательной фигуры с анимированной точкой.
/// Получает готовую геометрию из BreathShapeShifter, который управляет морфингом между формами.
class BreathShapePainter extends CustomPainter {
  final BreathShapeShifter shapeShifter;
  final double normalizedTime; // 0.0 - 1.0

  // Визуальные параметры
  final Color shapeColor;
  final Color pointColor;
  final double shapeStrokeWidth;
  final double pointRadius;

  BreathShapePainter({
    required this.shapeShifter,
    required this.normalizedTime,
    this.shapeColor = const Color(0xFF00D9FF),
    this.pointColor = const Color(0xFFFFFFFF),
    this.shapeStrokeWidth = 3.0,
    this.pointRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Получаем готовый Path из ShapeShifter
    final path = shapeShifter.getCurrentPath();

    // 1. Рисуем фигуру
    _drawShape(canvas, path);

    // 2. Рисуем точку
    _drawPoint(canvas, path);
  }

  /// Отрисовка геометрии фигуры с трёхслойным эффектом
  void _drawShape(Canvas canvas, Path path) {
    // Слой 1: Внешний glow (blur)
    final glowPaint = Paint()
      ..color = shapeColor.withValues(alpha: 0.3)
      ..strokeWidth = shapeStrokeWidth + 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, glowPaint);

    // Слой 2: Основная линия
    final shapePaint = Paint()
      ..color = shapeColor
      ..strokeWidth = shapeStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, shapePaint);

    // Слой 3: Внутренний highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = shapeStrokeWidth * 0.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, highlightPaint);
  }

  /// Отрисовка анимированной точки
  void _drawPoint(Canvas canvas, Path path) {
    // Получаем позицию точки из ShapeShifter
    final pointPosition = shapeShifter.getPointPosition(normalizedTime);

    // Слой 1: Внешний glow
    final glowPaint = Paint()
      ..color = pointColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(pointPosition, pointRadius * 2.5, glowPaint);

    // Слой 2: Средний glow
    final midGlowPaint = Paint()
      ..color = pointColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(pointPosition, pointRadius * 1.5, midGlowPaint);

    // Слой 3: Основная точка
    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointPosition, pointRadius, pointPaint);

    // Слой 4: Центральный highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointPosition, pointRadius * 0.4, highlightPaint);
  }

  @override
  bool shouldRepaint(BreathShapePainter oldDelegate) {
    return oldDelegate.normalizedTime != normalizedTime;
  }
}
