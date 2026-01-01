import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Models/BreathExercise.dart';
import 'dart:math' as math;

/// CustomPainter для отрисовки дыхательной фигуры с анимированной точкой
class BreathShapePainter extends CustomPainter {
  final BreathShape shape;
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

    // 1. Рисуем фигуру
    _drawShape(canvas, center, shapeSize);

    // 2. Рисуем точку
    _drawPoint(canvas, center, shapeSize);
  }

  /// Отрисовка геометрии фигуры
  void _drawShape(Canvas canvas, Offset center, double shapeSize) {
    final path = _getShapePath(center, shapeSize);

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
  void _drawPoint(Canvas canvas, Offset center, double shapeSize) {
    final pointPosition = _getPointPosition(center, shapeSize, normalizedTime);

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

  /// Создание Path для выбранной формы
  Path _getShapePath(Offset center, double size) {
    switch (shape) {
      case BreathShape.square:
        return _createSquarePath(center, size);
      case BreathShape.triangle:
        return _createTrianglePath(
          center,
          size,
          triangleOrientation ?? TriangleOrientation.up,
        );
      case BreathShape.circle:
        return _createCirclePath(center, size);
    }
  }

  /// Квадрат
  Path _createSquarePath(Offset center, double size) {
    final halfSize = size / 2;
    final path = Path();

    // Начинаем с верхнего правого угла (по часовой стрелке)
    path.moveTo(center.dx + halfSize, center.dy - halfSize);
    path.lineTo(center.dx + halfSize, center.dy + halfSize); // вниз
    path.lineTo(center.dx - halfSize, center.dy + halfSize); // влево
    path.lineTo(center.dx - halfSize, center.dy - halfSize); // вверх
    path.close(); // замыкаем к начальной точке

    return path;
  }

  /// Треугольник
  Path _createTrianglePath(
    Offset center,
    double size,
    TriangleOrientation orientation,
  ) {
    final path = Path();
    final radius = size / 2;

    // Базовые точки равностороннего треугольника (вершина вверху)
    final point1 = Offset(center.dx, center.dy - radius);
    final point2 = Offset(
      center.dx + radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );
    final point3 = Offset(
      center.dx - radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );

    // Применяем поворот в зависимости от ориентации
    List<Offset> points = [point1, point2, point3];

    switch (orientation) {
      case TriangleOrientation.down:
        points = _rotatePoints(points, center, math.pi);
        break;
      case TriangleOrientation.up:
        // уже в нужной ориентации
        break;
    }

    path.moveTo(points[0].dx, points[0].dy);
    path.lineTo(points[1].dx, points[1].dy);
    path.lineTo(points[2].dx, points[2].dy);
    path.close();

    return path;
  }

  /// Круг
  Path _createCirclePath(Offset center, double size) {
    final path = Path();
    final radius = size / 2;

    path.addOval(Rect.fromCircle(center: center, radius: radius));

    return path;
  }

  /// Вычисление позиции точки на траектории
  Offset _getPointPosition(Offset center, double size, double time) {
    switch (shape) {
      case BreathShape.square:
        return _getSquarePointPosition(center, size, time);
      case BreathShape.triangle:
        return _getTrianglePointPosition(
          center,
          size,
          time,
          triangleOrientation ?? TriangleOrientation.up,
        );
      case BreathShape.circle:
        return _getCirclePointPosition(center, size, time);
    }
  }

  /// Позиция точки на квадрате (движется по периметру)
  Offset _getSquarePointPosition(Offset center, double size, double time) {
    final halfSize = size / 2;

    // Делим периметр на 4 стороны (по 0.25 времени на каждую)
    if (time < 0.25) {
      // Правая сторона: вниз
      final progress = time / 0.25;
      return Offset(
        center.dx + halfSize,
        center.dy - halfSize + (size * progress),
      );
    } else if (time < 0.5) {
      // Нижняя сторона: влево
      final progress = (time - 0.25) / 0.25;
      return Offset(
        center.dx + halfSize - (size * progress),
        center.dy + halfSize,
      );
    } else if (time < 0.75) {
      // Левая сторона: вверх
      final progress = (time - 0.5) / 0.25;
      return Offset(
        center.dx - halfSize,
        center.dy + halfSize - (size * progress),
      );
    } else {
      // Верхняя сторона: вправо
      final progress = (time - 0.75) / 0.25;
      return Offset(
        center.dx - halfSize + (size * progress),
        center.dy - halfSize,
      );
    }
  }

  /// Позиция точки на треугольнике
  Offset _getTrianglePointPosition(
    Offset center,
    double size,
    double time,
    TriangleOrientation orientation,
  ) {
    final radius = size / 2;

    // Базовые вершины
    final point1 = Offset(center.dx, center.dy - radius);
    final point2 = Offset(
      center.dx + radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );
    final point3 = Offset(
      center.dx - radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );

    List<Offset> points = [point1, point2, point3];

    // Применяем поворот
    switch (orientation) {
      case TriangleOrientation.down:
        points = _rotatePoints(points, center, math.pi);
        break;
      case TriangleOrientation.up:
        break;
    }

    // Движение по трем сторонам
    if (time < 0.333) {
      final progress = time / 0.333;
      return Offset.lerp(points[0], points[1], progress)!;
    } else if (time < 0.666) {
      final progress = (time - 0.333) / 0.333;
      return Offset.lerp(points[1], points[2], progress)!;
    } else {
      final progress = (time - 0.666) / 0.334;
      return Offset.lerp(points[2], points[0], progress)!;
    }
  }

  /// Позиция точки на круге
  Offset _getCirclePointPosition(Offset center, double size, double time) {
    final radius = size / 2;
    final angle = time * 2 * math.pi - math.pi / 2; // Начинаем сверху

    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  /// Вспомогательная функция поворота точек
  List<Offset> _rotatePoints(List<Offset> points, Offset center, double angle) {
    return points.map((point) {
      final dx = point.dx - center.dx;
      final dy = point.dy - center.dy;

      final newX = dx * math.cos(angle) - dy * math.sin(angle);
      final newY = dx * math.sin(angle) + dy * math.cos(angle);

      return Offset(center.dx + newX, center.dy + newY);
    }).toList();
  }

  @override
  bool shouldRepaint(BreathShapePainter oldDelegate) {
    return oldDelegate.normalizedTime != normalizedTime ||
        oldDelegate.shape != shape ||
        oldDelegate.triangleOrientation != triangleOrientation;
  }
}
