import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapeGeometry.dart';

/// CustomPainter для отрисовки дыхательной фигуры с анимированной точкой.
/// Не знает о геометрии фигур — получает готовые вершины из BreathShapeGeometry.
class BreathShapePainter extends CustomPainter {
  final SetShape shape;
  final double normalizedTime; // 0.0 - 1.0
  final TriangleOrientation? triangleOrientation;

  // Визуальные параметры
  final Color shapeColor;
  final Color pointColor;
  final double shapeStrokeWidth;
  final double pointRadius;

  BreathShapePainter({
    required this.shape,
    required this.normalizedTime,
    this.triangleOrientation,
    this.shapeColor = const Color(0xFF00D9FF),
    this.pointColor = const Color(0xFFFFFFFF),
    this.shapeStrokeWidth = 3.0,
    this.pointRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Центрируем всё относительно canvas
    final center = Offset(size.width / 2, size.height / 2);

    // Размер фигуры — 70% от минимального измерения экрана
    final shapeSize = math.min(size.width, size.height) * 0.7;

    // Получаем геометрию из чистого геометрического слоя
    final vertices = BreathShapeGeometry.getVertices(
      shape: shape,
      center: center,
      size: shapeSize,
      triangleOrientation: triangleOrientation,
    );

    final path = BreathShapeGeometry.verticesToPath(vertices);

    // 1. Рисуем фигуру
    _drawShape(canvas, path);

    // 2. Рисуем точку
    _drawPoint(canvas, path, center);
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
  void _drawPoint(Canvas canvas, Path path, Offset fallbackCenter) {
    final pointPosition = _getPointPosition(path, normalizedTime, fallbackCenter);

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

  /// Вычисление позиции точки на траектории через PathMetrics
  Offset _getPointPosition(Path path, double time, Offset fallbackCenter) {
    // Быстрая проверка на пустой path
    if (path.getBounds().isEmpty) {
      return fallbackCenter;
    }

    final pathMetrics = path.computeMetrics().toList();

    if (pathMetrics.isEmpty) {
      return fallbackCenter;
    }

    final totalLength = pathMetrics.fold(
      0.0,
      (prev, metric) => prev + metric.length,
    );

    if (totalLength == 0) {
      return fallbackCenter; // все точки совпадают
    }

    final distance = totalLength * (time % 1.0);
    var accumulated = 0.0;

    for (final metric in pathMetrics) {
      if (accumulated + metric.length >= distance) {
        final tangent = metric.getTangentForOffset(distance - accumulated);
        return tangent?.position ?? fallbackCenter;
      }
      accumulated += metric.length;
    }

    // Если по какой-то причине вышли за пределы — берём конец последнего сегмента
    final lastMetric = pathMetrics.last;
    final lastTangent = lastMetric.getTangentForOffset(lastMetric.length);
    return lastTangent?.position ?? fallbackCenter;
  }

  @override
  bool shouldRepaint(BreathShapePainter oldDelegate) {
    return oldDelegate.normalizedTime != normalizedTime ||
        oldDelegate.shape != shape ||
        oldDelegate.triangleOrientation != triangleOrientation;
  }
}
