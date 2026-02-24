import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'dart:math' as math;

class BreathShapeShifter extends ChangeNotifier {
  static const int numSegments = 120;

  SetShape _currentShape;
  SetShape _startShape;
  List<Offset> _currentPoints = [];
  double _morphProgress = 1.0;
  AnimationController? _morphController;
  Offset _center = Offset.zero;
  double _size = 0.0;

  Path? _cachedPath;

  BreathShapeShifter({required SetShape initialShape})
      : _currentShape = initialShape,
        _startShape = initialShape;

  void initialize(Offset center, double size, TickerProvider vsync) {
    _center = center;
    _size = size;

    // Генерируем начальные точки для текущей формы
    _currentPoints = _generateShapePoints(_currentShape);
    _cachedPath = null;

    // Создаём контроллер морфинга
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    )..addListener(_onMorphTick);

    // Устанавливаем прогресс = 1.0 чтобы форма была завершённой
    _morphProgress = 1.0;
  }

  void updateBounds(Offset center, double size) {
    if (_center == center && _size == size) return;

    final scaleX = size / _size;
    final scaleY = size / _size;
    final dx = center.dx - _center.dx;
    final dy = center.dy - _center.dy;

    _center = center;
    _size = size;

    _currentPoints = _currentPoints.map((p) {
      return Offset(
        _center.dx + (p.dx - _center.dx + dx) * scaleX,
        _center.dy + (p.dy - _center.dy + dy) * scaleY,
      );
    }).toList();

    _cachedPath = null;
    notifyListeners();
  }

  void morphTo(SetShape newShape) {
    if (newShape == _currentShape) {
      return;
    }

    _morphController?.stop();
    _startShape = _currentShape;
    _currentShape = newShape;
    _morphProgress = 0.0;
    _morphController?.forward(from: 0.0);
  }

  void _onMorphTick() {
    _morphProgress = _morphController?.value ?? 1.0;
    final t = Curves.easeInOut.transform(_morphProgress);

    // Проверяем тип морфинга
    if (_isRectangularMorph(_startShape, _currentShape)) {
      // Для треугольник↔квадрат используем старую систему через Path
      final path = _buildGeometricPath(_startShape, t, _currentShape);
      _currentPoints = _redistributePointsAlongPath(path);
    } else {
      // Для морфингов с кругом используем интерполяцию точек
      final startPoints = _generateShapePoints(_startShape);
      final endPoints = _generateShapePoints(_currentShape);

      _currentPoints = List.generate(numSegments, (i) {
        return Offset.lerp(startPoints[i], endPoints[i], t)!;
      });
    }

    _cachedPath = null;
    notifyListeners();
  }

  // Проверяем, является ли морфинг прямоугольным (без круга)
  bool _isRectangularMorph(SetShape from, SetShape to) {
    return from != SetShape.circle && to != SetShape.circle;
  }

  Path getCurrentPath() {
    if (_cachedPath != null) return _cachedPath!;

    final path = Path();
    if (_currentPoints.isEmpty) return path;

    path.moveTo(_currentPoints[0].dx, _currentPoints[0].dy);
    for (int i = 1; i < _currentPoints.length; i++) {
      path.lineTo(_currentPoints[i].dx, _currentPoints[i].dy);
    }
    path.close();
    _cachedPath = path;
    return path;
  }

  Offset getPointPosition(double normalizedTime) {
    if (_currentPoints.isEmpty) return _center;

    final path = getCurrentPath();
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isEmpty) return _center;

    final totalLength = pathMetrics.fold(0.0, (sum, m) => sum + m.length);
    if (totalLength == 0) return _center;

    final distance = totalLength * (normalizedTime % 1.0);
    var accumulated = 0.0;

    for (final metric in pathMetrics) {
      if (accumulated + metric.length >= distance) {
        final tangent = metric.getTangentForOffset(distance - accumulated);
        return tangent?.position ?? _center;
      }
      accumulated += metric.length;
    }

    return pathMetrics.last.getTangentForOffset(pathMetrics.last.length)?.position ?? _center;
  }

  // ============================================================
  // ГЕНЕРАЦИЯ 120 ТОЧЕК ДЛЯ КАЖДОЙ ФИГУРЫ
  // ============================================================

  List<Offset> _generateShapePoints(SetShape shape) {
    switch (shape) {
      case SetShape.circle:
        return _generateCirclePoints();
      case SetShape.square:
        return _generateSquarePoints();
      case SetShape.triangleUp:
        return _generateTriangleUpPoints();
      case SetShape.triangleDown:
        return _generateTriangleDownPoints();
    }
  }

  // КРУГ: начинаем с нижней точки (50, 100), идём ПО ЧАСОВОЙ СТРЕЛКЕ
  List<Offset> _generateCirclePoints() {
    final points = <Offset>[];
    final half = _size / 2;

    for (int i = 0; i < numSegments; i++) {
      // Начинаем с угла π/2 (низ) и идём ПО часовой стрелке (вычитаем угол)
      final angle = math.pi / 2 + (2 * math.pi * i / numSegments);
      final x = _center.dx + half * math.cos(angle);
      final y = _center.dy + half * math.sin(angle);
      points.add(Offset(x, y));
    }

    return points;
  }

  // КВАДРАТ: начинаем с левого нижнего угла (0, 100), идём ПО ЧАСОВОЙ
  List<Offset> _generateSquarePoints() {
    final points = <Offset>[];
    final half = _size / 2;

    final pointsPerSide = numSegments ~/ 4;

    // Левая сторона: (0, 100) → (0, 0) - идём вверх
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset(
        _center.dx - half,
        _center.dy + half - _size * t,
      ));
    }

    // Верхняя сторона: (0, 0) → (100, 0) - идём вправо
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset(
        _center.dx - half + _size * t,
        _center.dy - half,
      ));
    }

    // Правая сторона: (100, 0) → (100, 100) - идём вниз
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset(
        _center.dx + half,
        _center.dy - half + _size * t,
      ));
    }

    // Нижняя сторона: (100, 100) → (0, 100) - идём влево
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset(
        _center.dx + half - _size * t,
        _center.dy + half,
      ));
    }

    return points;
  }

  // ТРЕУГОЛЬНИК ВВЕРХ: начинаем с левого нижнего угла (0, 100), идём ПО ЧАСОВОЙ
  List<Offset> _generateTriangleUpPoints() {
    final points = <Offset>[];
    final half = _size / 2;

    final pointsPerSide = numSegments ~/ 3;

    final topVertex = Offset(_center.dx, _center.dy - half);
    final leftVertex = Offset(_center.dx - half, _center.dy + half);
    final rightVertex = Offset(_center.dx + half, _center.dy + half);

    // Левая сторона: (0, 100) → (50, 0)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(leftVertex, topVertex, t)!);
    }

    // Правая сторона: (50, 0) → (100, 100)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(topVertex, rightVertex, t)!);
    }

    // Нижняя сторона: (100, 100) → (0, 100)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(rightVertex, leftVertex, t)!);
    }

    return points;
  }

  // ТРЕУГОЛЬНИК ВНИЗ: начинаем с вершины (50, 100), идём ПО ЧАСОВОЙ
  List<Offset> _generateTriangleDownPoints() {
    final points = <Offset>[];
    final half = _size / 2;

    final pointsPerSide = numSegments ~/ 3;

    final bottomVertex = Offset(_center.dx, _center.dy + half);
    final leftVertex = Offset(_center.dx - half, _center.dy - half);
    final rightVertex = Offset(_center.dx + half, _center.dy - half);

    // Левая сторона: (50, 100) → (0, 0)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(bottomVertex, leftVertex, t)!);
    }

    // Верхняя сторона: (0, 0) → (100, 0)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(leftVertex, rightVertex, t)!);
    }

    // Правая сторона: (100, 0) → (50, 100)
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      points.add(Offset.lerp(rightVertex, bottomVertex, t)!);
    }

    return points;
  }

  // ============================================================
  // СТАРАЯ СИСТЕМА ДЛЯ ПРЯМОУГОЛЬНЫХ МОРФИНГОВ (треугольник↔квадрат)
  // ============================================================

  Path _buildGeometricPath(SetShape from, double t, SetShape to) {
    if ((from == SetShape.square && to == SetShape.triangleUp) ||
        (from == SetShape.triangleUp && to == SetShape.square)) {
      final progress = from == SetShape.square ? t : (1.0 - t);
      return _buildTrapezoidTopNarrowing(progress);
    }

    if ((from == SetShape.square && to == SetShape.triangleDown) ||
        (from == SetShape.triangleDown && to == SetShape.square)) {
      final progress = from == SetShape.square ? t : (1.0 - t);
      return _buildTrapezoidBottomNarrowing(progress);
    }

    if ((from == SetShape.triangleUp && to == SetShape.triangleDown) ||
        (from == SetShape.triangleDown && to == SetShape.triangleUp)) {
      final progress = from == SetShape.triangleUp ? t : (1.0 - t);
      return _buildTrapezoidSymmetric(progress);
    }

    // Fallback
    return Path()..addOval(Rect.fromCenter(center: _center, width: _size, height: _size));
  }

  Path _buildTrapezoidTopNarrowing(double t) {
    final half = _size / 2;

    final topWidth = _size * (1.0 - t);
    final topLeft = Offset(_center.dx - topWidth / 2, _center.dy - half);
    final topRight = Offset(_center.dx + topWidth / 2, _center.dy - half);

    final bottomLeft = Offset(_center.dx - half, _center.dy + half);
    final bottomRight = Offset(_center.dx + half, _center.dy + half);

    return Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();
  }

  Path _buildTrapezoidBottomNarrowing(double t) {
    final half = _size / 2;

    final topLeft = Offset(_center.dx - half, _center.dy - half);
    final topRight = Offset(_center.dx + half, _center.dy - half);

    final bottomWidth = _size * (1.0 - t);
    final bottomLeft = Offset(_center.dx - bottomWidth / 2, _center.dy + half);
    final bottomRight = Offset(_center.dx + bottomWidth / 2, _center.dy + half);

    return Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();
  }

  Path _buildTrapezoidSymmetric(double t) {
    final half = _size / 2;

    final topWidth = _size * t;
    final topLeft = Offset(_center.dx - topWidth / 2, _center.dy - half);
    final topRight = Offset(_center.dx + topWidth / 2, _center.dy - half);

    final bottomWidth = _size * (1.0 - t);
    final bottomLeft = Offset(_center.dx - bottomWidth / 2, _center.dy + half);
    final bottomRight = Offset(_center.dx + bottomWidth / 2, _center.dy + half);

    return Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();
  }

  List<Offset> _redistributePointsAlongPath(Path path) {
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isEmpty) return List.filled(numSegments, _center);

    final totalLength = pathMetrics.fold(0.0, (sum, m) => sum + m.length);
    if (totalLength == 0) return List.filled(numSegments, _center);

    final points = <Offset>[];

    for (int i = 0; i < numSegments; i++) {
      final position = i / numSegments;
      final distance = position * totalLength;
      var accumulated = 0.0;

      for (final metric in pathMetrics) {
        if (accumulated + metric.length >= distance) {
          final tangent = metric.getTangentForOffset(distance - accumulated);
          if (tangent != null) {
            points.add(tangent.position);
            break;
          }
        }
        accumulated += metric.length;
      }
    }

    while (points.length < numSegments) {
      points.add(_center);
    }

    return points;
  }

  SetShape get currentShape => _currentShape;
  bool get isMorphing => _morphProgress < 1.0;
  double get morphProgress => _morphProgress;

  @override
  void dispose() {
    _morphController?.dispose();
    super.dispose();
  }
}
