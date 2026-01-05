import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'dart:math' as math;

/// Центральный "мозг" геометрии дыхательных фигур.
/// Управляет плавными переходами между формами через морфинг.
///
/// Принцип работы: хранит 120 точек, которые постоянно интерполируются
/// от текущей формы к целевой. Как мастер-кузнец, плавно перетягивающий
/// светящуюся нить из одной конфигурации в другую.
class BreathShapeShifter extends ChangeNotifier {
  /// Фиксированное количество точек для всех фигур
  static const int numSegments = 120;

  /// Текущая форма
  SetShape _currentShape;

  /// Ориентация треугольника (если применимо)
  TriangleOrientation _triangleOrientation;

  /// Текущие координаты 120 точек (живое состояние нити)
  List<Offset> _currentPoints = [];

  /// Стартовые точки для морфинга
  List<Offset> _startPoints = [];

  /// Целевые точки для морфинга
  List<Offset> _targetPoints = [];

  /// Прогресс морфинга от 0.0 (start) до 1.0 (target)
  double _morphProgress = 1.0;

  /// Контроллер анимации морфинга
  AnimationController? _morphController;

  /// Центр и размер фигуры
  Offset _center = Offset.zero;
  double _size = 0.0;

  BreathShapeShifter({
    required SetShape initialShape,
    TriangleOrientation triangleOrientation = TriangleOrientation.up,
  })  : _currentShape = initialShape,
        _triangleOrientation = triangleOrientation;

  /// Инициализация с параметрами canvas
  void initialize(Offset center, double size, TickerProvider vsync) {
    _center = center;
    _size = size;

    // Генерируем начальные точки
    _currentPoints = _generateShapePoints(_currentShape, _triangleOrientation);

    // Создаём контроллер для морфинга (800ms с easeInOut)
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    )..addListener(_onMorphTick);
  }

  /// Обновление размеров (при изменении размера экрана)
  void updateBounds(Offset center, double size) {
    if (_center == center && _size == size) return;

    final oldCenter = _center;
    final oldSize = _size;

    _center = center;
    _size = size;

    // Пересчитываем все точки с новыми параметрами
    if (_morphProgress < 1.0) {
      // Во время морфинга пересчитываем и start, и target
      final scaleX = center.dx / oldCenter.dx;
      final scaleY = center.dy / oldCenter.dy;
      final sizeScale = size / oldSize;

      _startPoints = _rescalePoints(_startPoints, oldCenter, center, sizeScale);
      _targetPoints = _rescalePoints(_targetPoints, oldCenter, center, sizeScale);
      _currentPoints = _rescalePoints(_currentPoints, oldCenter, center, sizeScale);
    } else {
      // Статичное состояние — просто регенерируем
      _currentPoints = _generateShapePoints(_currentShape, _triangleOrientation);
    }

    notifyListeners();
  }

  /// Запуск морфинга к новой форме
  void morphTo(SetShape newShape, {TriangleOrientation? orientation}) {
    if (newShape == _currentShape &&
        (orientation == null || orientation == _triangleOrientation)) {
      return; // Уже в этой форме
    }

    // Прерываем текущий морфинг если он идёт
    _morphController?.stop();

    // Фиксируем текущее состояние как старт
    _startPoints = List.from(_currentPoints);

    // Генерируем целевую форму
    final targetOrientation = orientation ?? _triangleOrientation;
    _targetPoints = _generateShapePoints(newShape, targetOrientation);

    // Обновляем состояние
    _currentShape = newShape;
    _triangleOrientation = targetOrientation;

    // Запускаем анимацию
    _morphProgress = 0.0;
    _morphController?.forward(from: 0.0);
  }

  /// Обработчик тика анимации морфинга
  void _onMorphTick() {
    _morphProgress = _morphController?.value ?? 1.0;

    // Интерполируем каждую точку
    for (int i = 0; i < numSegments; i++) {
      _currentPoints[i] = Offset.lerp(
        _startPoints[i],
        _targetPoints[i],
        Curves.easeInOut.transform(_morphProgress),
      )!;
    }

    notifyListeners();
  }

  /// Получить текущий Path фигуры
  Path getCurrentPath() {
    final path = Path();
    if (_currentPoints.isEmpty) return path;

    path.moveTo(_currentPoints[0].dx, _currentPoints[0].dy);
    for (int i = 1; i < _currentPoints.length; i++) {
      path.lineTo(_currentPoints[i].dx, _currentPoints[i].dy);
    }
    path.close();

    return path;
  }

  /// Получить позицию бегущей точки на текущем контуре
  /// [normalizedTime] - время от 0.0 до 1.0
  Offset getPointPosition(double normalizedTime) {
    if (_currentPoints.isEmpty) return _center;

    final path = getCurrentPath();
    final pathMetrics = path.computeMetrics();
    final totalLength = pathMetrics.fold(
      0.0,
      (prev, metric) => prev + metric.length,
    );

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

    final lastTangent = pathMetrics.last.getTangentForOffset(
      pathMetrics.last.length,
    );
    return lastTangent?.position ?? _center;
  }

  /// Генерация 120 точек для заданной формы
  List<Offset> _generateShapePoints(
    SetShape shape,
    TriangleOrientation orientation,
  ) {
    switch (shape) {
      case SetShape.circle:
        return _generateCirclePoints();
      case SetShape.square:
        return _generateSquarePoints();
      case SetShape.triangle:
        return _generateTrianglePoints(orientation);
    }
  }

  /// Генерация точек круга (старт с верхней точки, по часовой)
  List<Offset> _generateCirclePoints() {
    final radius = _size / 2;
    final points = <Offset>[];

    for (int i = 0; i < numSegments; i++) {
      // Начинаем с -π/2 (верхняя точка)
      final angle = -math.pi / 2 + (i / numSegments) * 2 * math.pi;
      points.add(Offset(
        _center.dx + radius * math.cos(angle),
        _center.dy + radius * math.sin(angle),
      ));
    }

    return points;
  }

  /// Генерация точек квадрата (старт с верхней центральной точки)
  /// 4 стороны × 30 точек = 120 точек
  List<Offset> _generateSquarePoints() {
    final halfSize = _size / 2;
    final pointsPerSide = numSegments ~/ 4; // 30
    final points = <Offset>[];

    // Верхняя сторона: слева направо (начинаем с центра верхней стороны)
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset(
        _center.dx - halfSize + _size * progress,
        _center.dy - halfSize,
      ));
    }

    // Правая сторона: сверху вниз
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset(
        _center.dx + halfSize,
        _center.dy - halfSize + _size * progress,
      ));
    }

    // Нижняя сторона: справа налево
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset(
        _center.dx + halfSize - _size * progress,
        _center.dy + halfSize,
      ));
    }

    // Левая сторона: снизу вверх
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset(
        _center.dx - halfSize,
        _center.dy + halfSize - _size * progress,
      ));
    }

    return points;
  }

  /// Генерация точек треугольника (старт с верхней вершины)
  /// 3 стороны × 40 точек = 120 точек
  List<Offset> _generateTrianglePoints(TriangleOrientation orientation) {
    final radius = _size / 2;
    final pointsPerSide = numSegments ~/ 3; // 40
    final points = <Offset>[];

    // Вершины равностороннего треугольника (вершина вверх)
    final topVertex = Offset(_center.dx, _center.dy - radius);
    final rightVertex = Offset(
      _center.dx + radius * math.cos(math.pi / 6),
      _center.dy + radius * math.sin(math.pi / 6),
    );
    final leftVertex = Offset(
      _center.dx - radius * math.cos(math.pi / 6),
      _center.dy + radius * math.sin(math.pi / 6),
    );

    List<Offset> vertices = [topVertex, rightVertex, leftVertex];

    // Поворот для ориентации вниз
    if (orientation == TriangleOrientation.down) {
      vertices = _rotatePoints(vertices, _center, math.pi);
    }

    // Сторона 1: от vertices[0] к vertices[1]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset.lerp(vertices[0], vertices[1], progress)!);
    }

    // Сторона 2: от vertices[1] к vertices[2]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset.lerp(vertices[1], vertices[2], progress)!);
    }

    // Сторона 3: от vertices[2] к vertices[0]
    for (int i = 0; i < pointsPerSide; i++) {
      final progress = i / pointsPerSide;
      points.add(Offset.lerp(vertices[2], vertices[0], progress)!);
    }

    return points;
  }

  /// Поворот точек вокруг центра
  List<Offset> _rotatePoints(List<Offset> points, Offset center, double angle) {
    return points.map((point) {
      final dx = point.dx - center.dx;
      final dy = point.dy - center.dy;

      final newX = dx * math.cos(angle) - dy * math.sin(angle);
      final newY = dx * math.sin(angle) + dy * math.cos(angle);

      return Offset(center.dx + newX, center.dy + newY);
    }).toList();
  }

  /// Масштабирование точек при изменении размера canvas
  List<Offset> _rescalePoints(
    List<Offset> points,
    Offset oldCenter,
    Offset newCenter,
    double sizeScale,
  ) {
    return points.map((point) {
      // Переводим в относительные координаты
      final relativeX = (point.dx - oldCenter.dx) * sizeScale;
      final relativeY = (point.dy - oldCenter.dy) * sizeScale;

      // Применяем новый центр
      return Offset(newCenter.dx + relativeX, newCenter.dy + relativeY);
    }).toList();
  }

  /// Текущая форма
  SetShape get currentShape => _currentShape;

  /// Идёт ли морфинг в данный момент
  bool get isMorphing => _morphProgress < 1.0;

  /// Прогресс морфинга
  double get morphProgress => _morphProgress;

  @override
  void dispose() {
    _morphController?.dispose();
    super.dispose();
  }
}
