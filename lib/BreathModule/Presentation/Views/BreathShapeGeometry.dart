import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'dart:math' as math;

/// Чистый геометрический слой для генерации вершин дыхательных фигур.
/// Не знает ничего про Canvas, Painter, анимации или дыхание.
/// Единственная ответственность: выдавать детерминированный массив вершин
/// фиксированной размерности для заданной фигуры.
class BreathShapeGeometry {
  /// Унифицированное количество сегментов для всех фигур
  /// Делится на 3 (для треугольника: 40 точек на сторону)
  /// Делится на 4 (для квадрата: 30 точек на сторону)
  static const int numSegments = 120;

  /// Генерирует массив вершин для указанной фигуры
  ///
  /// [shape] - тип фигуры (круг, квадрат, треугольник)
  /// [center] - центр фигуры в координатах
  /// [size] - размер фигуры (диаметр для круга, сторона для квадрата и т.д.)
  /// [triangleOrientation] - ориентация треугольника (если применимо)
  ///
  /// Возвращает List<Offset> длиной ровно [numSegments] точек
  static List<Offset> getVertices({
    required SetShape shape,
    required Offset center,
    required double size,
    TriangleOrientation? triangleOrientation,
  }) {
    switch (shape) {
      case SetShape.square:
        return _getSquareVertices(center, size);
      case SetShape.triangle:
        return _getTriangleVertices(
          center,
          size,
          triangleOrientation ?? TriangleOrientation.up,
        );
      case SetShape.circle:
        return _getCircleVertices(center, size);
    }
  }

  /// Генерирует вершины для квадрата
  /// Точки равномерно распределены по сторонам: top → right → bottom → left
  static List<Offset> _getSquareVertices(Offset center, double size) {
    final halfSize = size / 2;
    final pointsPerSide = numSegments ~/ 4;
    final List<Offset> vertices = [];

    // Верхняя сторона: слева направо
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      vertices.add(Offset(
        center.dx - halfSize + size * progress,
        center.dy - halfSize,
      ));
    }

    // Правая сторона: сверху вниз
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      vertices.add(Offset(
        center.dx + halfSize,
        center.dy - halfSize + size * progress,
      ));
    }

    // Нижняя сторона: справа налево
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      vertices.add(Offset(
        center.dx + halfSize - size * progress,
        center.dy + halfSize,
      ));
    }

    // Левая сторона: снизу вверх
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      vertices.add(Offset(
        center.dx - halfSize,
        center.dy + halfSize - size * progress,
      ));
    }

    return vertices;
  }

  /// Генерирует вершины для треугольника
  /// Точки равномерно распределены по сторонам: side1 → side2 → side3
  static List<Offset> _getTriangleVertices(
    Offset center,
    double size,
    TriangleOrientation orientation,
  ) {
    final radius = size / 2;
    final pointsPerSide = numSegments ~/ 3;
    final List<Offset> vertices = [];

    // Базовые вершины равностороннего треугольника (вершина вверх)
    Offset point1 = Offset(center.dx, center.dy - radius);
    Offset point2 = Offset(
      center.dx + radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );
    Offset point3 = Offset(
      center.dx - radius * math.cos(math.pi / 6),
      center.dy + radius * math.sin(math.pi / 6),
    );

    List<Offset> corners = [point1, point2, point3];

    // Применяем поворот для ориентации вниз
    if (orientation == TriangleOrientation.down) {
      corners = _rotatePoints(corners, center, math.pi);
    }

    // Сторона 1: от corners[0] к corners[1]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide.toDouble();
      vertices.add(Offset.lerp(corners[0], corners[1], progress)!);
    }

    // Сторона 2: от corners[1] к corners[2]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide.toDouble();
      vertices.add(Offset.lerp(corners[1], corners[2], progress)!);
    }

    // Сторона 3: от corners[2] к corners[0]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide.toDouble();
      vertices.add(Offset.lerp(corners[2], corners[0], progress)!);
    }

    return vertices;
  }

  /// Генерирует вершины для круга
  /// Точки равномерно распределены по окружности, начиная с 0 радиан
  static List<Offset> _getCircleVertices(Offset center, double size) {
    final radius = size / 2;
    final List<Offset> vertices = [];

    for (int i = 0; i < numSegments; i++) {
      final angle = (i / numSegments.toDouble()) * 2 * math.pi;
      vertices.add(Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      ));
    }

    return vertices;
  }

  /// Поворачивает массив точек вокруг центра на заданный угол
  static List<Offset> _rotatePoints(
    List<Offset> points,
    Offset center,
    double angle,
  ) {
    return points.map((point) {
      final dx = point.dx - center.dx;
      final dy = point.dy - center.dy;

      final newX = dx * math.cos(angle) - dy * math.sin(angle);
      final newY = dx * math.sin(angle) + dy * math.cos(angle);

      return Offset(center.dx + newX, center.dy + newY);
    }).toList();
  }

  /// Создаёт Path из массива вершин (вспомогательный метод)
  /// Полезен для Painter'а, но не является обязательной частью геометрии
  static Path verticesToPath(List<Offset> vertices) {
    final path = Path();
    if (vertices.isNotEmpty) {
      path.moveTo(vertices[0].dx, vertices[0].dy);
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(vertices[i].dx, vertices[i].dy);
      }
      path.close();
    }
    return path;
  }
}
