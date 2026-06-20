import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class BreathMotionEngine extends ChangeNotifier {
  // Состояние движка
  double _position = 0.0;
  double _currentVelocity = 0.0;
  double _targetVelocity = 0.0;
  double _targetDurationMs = 0.0;
  double _elapsedMs = 0.0;
  bool _isActive = false;

  // Фазовая структура цикла
  int _totalPhases = 0;
  int _currentPhaseIndex = 0;
  int _remainingPhaseTicks = 0;
  double _phaseTargetPosition = 1.0;

  // Данные от ViewModel
  double _smoothedIntervalMs = 1000.0;
  bool _isFirstInterval = true;

  // Константы
  static const double _smoothingFactor = 0.2;
  // Постоянная времени разгона скорости как ДОЛЯ длительности фазы (а не
  // фиксированная в мс). Это делает поведение масштабно-инвариантным: разгон
  // занимает один и тот же процент фазы хоть для 1с, хоть для 20с. 0.1 → полка
  // достигается примерно к 25% фазы (≈2.5 постоянных времени).
  static const double _rampTimeConstantFraction = 0.1;
  // Ниже этого остатка времени фазы целевая скорость не пересчитывается
  // (remainingDist/remainingTime у самого конца разносит в бесконечность) —
  // точка докатывается на текущей скорости.
  static const double _minRemainingTimeMs = 16.0;

  // Ticker
  late final Ticker _ticker;
  Duration? _previousElapsed;

  BreathMotionEngine(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  // Публичные геттеры. Позиция заворачивается по модулю 1.0, а не зажимается:
  // на низу круга точка перетекает в следующий цикл без остановки (1.0 и 0.0 —
  // одна и та же точка на замкнутом контуре).
  double get normalizedPosition => _position % 1.0;
  bool get isActive => _isActive;

  // Конфигурация фаз
  void setPhaseInfo({required int totalPhases, required int currentPhaseIndex}) {
    if (totalPhases <= 0) {
      _totalPhases = 0;
      _currentPhaseIndex = 0;
      _phaseTargetPosition = 1.0;
      return;
    }

    _totalPhases = totalPhases;
    _currentPhaseIndex = currentPhaseIndex.clamp(0, totalPhases - 1);
    _phaseTargetPosition = (_currentPhaseIndex + 1) / _totalPhases;
  }

  // Управление активностью
  void setActive(bool active) {
    _isActive = active;

    if (_isActive && !_ticker.isActive) {
      _previousElapsed = null;
      _ticker.start();
    } else if (!_isActive && _ticker.isActive) {
      _ticker.stop();
    }
  }

  // Подача "топлива" от ViewModel (тики до конца ТЕКУЩЕЙ фазы)
  void setRemainingPhaseTicks(int ticks) {
    _remainingPhaseTicks = ticks < 0 ? 0 : ticks;
    _targetDurationMs = _remainingPhaseTicks * _smoothedIntervalMs;
    _elapsedMs = 0.0;

    // Пересчитываем целевую скорость сразу относительно цели текущей фазы
    final double remainingDistance = _phaseTargetPosition - _position;
    if (_targetDurationMs > 0 && remainingDistance > 0) {
      _targetVelocity = remainingDistance / _targetDurationMs;
    } else {
      _targetVelocity = 0.0;
    }
  }

  void setIntervalMs(int intervalMs) {
    if (intervalMs <= 0) return;

    if (_isFirstInterval) {
      _smoothedIntervalMs = intervalMs.toDouble();
      _isFirstInterval = false;
    } else {
      _smoothedIntervalMs =
      _smoothedIntervalMs + _smoothingFactor * (intervalMs.toDouble() - _smoothedIntervalMs);
    }
  }

  // Сброс позиции. preserveVelocity=true сохраняет текущую скорость — для
  // границы цикла/упражнения, где движение должно перетекать в следующую
  // итерацию без остановки. На старте сессии и при входе в отдых скорость
  // обнуляется (точка стартует с нуля).
  void resetPosition([double newPosition = 0.0, bool preserveVelocity = false]) {
    _position = newPosition;
    if (!preserveVelocity) {
      _currentVelocity = 0.0;
      _targetVelocity = 0.0;
    }
    _elapsedMs = 0.0;

    notifyListeners();
  }

  // Основной цикл движка
  void _onTick(Duration elapsed) {
    if (_previousElapsed == null) {
      _previousElapsed = elapsed;
      return;
    }

    if (!_isActive) {
      return;
    }

    // 1. Вычисляем deltaTime
    final double deltaTimeMs = (elapsed - _previousElapsed!).inMicroseconds / 1000.0;
    _previousElapsed = elapsed;
    _elapsedMs += deltaTimeMs;

    // 2. Непрерывный пересчёт целевой скорости: сколько нужно, чтобы прийти
    //    в цель фазы ровно к её концу. Без заморозки — если на разгоне
    //    проскочили выше нужного, на следующих кадрах remainingDist/remainingTime
    //    станет меньше и скорость плавно скатится обратно (самокоррекция).
    final double remainingDistance = _phaseTargetPosition - _position;
    final double remainingTime = _targetDurationMs - _elapsedMs;

    if (remainingTime > _minRemainingTimeMs && remainingDistance > 0) {
      _targetVelocity = remainingDistance / remainingTime;
    }
    // иначе: у самого конца фазы цель не трогаем — докатываемся на текущей
    // скорости (её перенесёт в следующую фазу перенос скорости).

    // 3. Плавное изменение текущей скорости к целевой. Постоянная времени
    //    масштабируется от длительности фазы → разгон занимает фиксированную
    //    ДОЛЮ фазы независимо от того, 1 она секунда или 20.
    final double tauMs = _rampTimeConstantFraction * _targetDurationMs;
    final double damping = tauMs > 1.0 ? 1.0 / tauMs : 1.0;
    final double smoothingFactor = 1.0 - exp(-damping * deltaTimeMs);
    final double velocityDelta = (_targetVelocity - _currentVelocity) * smoothingFactor;
    _currentVelocity += velocityDelta;

    // 4. Обновление позиции. Позицию НЕ зажимаем на 1.0 — пусть переезжает за
    //    низ круга (геттер заворачивает по модулю), скорость не гасим. На границе
    //    цикла newCycle сделает resetPosition(preserveVelocity), и точка
    //    продолжит движение в новый цикл без остановки. Шаг 2 уже перестаёт
    //    разгонять к цели, как только её прошли (remainingDistance <= 0).
    final double deltaPosition = _currentVelocity * deltaTimeMs;
    _position += deltaPosition;

    // 5. Уведомление слушателей
    notifyListeners();
  }

  // Очистка ресурсов
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
