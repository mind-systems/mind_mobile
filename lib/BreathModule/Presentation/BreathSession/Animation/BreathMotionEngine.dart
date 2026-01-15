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
  bool _isLinearLocked = false;
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
  static const double _dampingFactor = 0.005;
  static const double _velocityTolerance = 1e-6;

  // Ticker
  late final Ticker _ticker;
  Duration? _previousElapsed;

  BreathMotionEngine(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  // Публичные геттеры
  double get normalizedPosition => _position.clamp(0.0, 1.0);
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
    _isLinearLocked = false;

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

  // Сброс позиции
  void resetPosition([double newPosition = 0.0]) {
    _position = newPosition;
    _currentVelocity = 0.0;
    _targetVelocity = 0.0;
    _elapsedMs = 0.0;
    _isLinearLocked = false;

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

    // 2. Пересчёт целевой скорости (если не заблокирован)
    if (!_isLinearLocked) {
      final double remainingDistance = _phaseTargetPosition - _position;
      final double remainingTime = _targetDurationMs - _elapsedMs;

      if (remainingTime > 0 && remainingDistance > 0) {
        _targetVelocity = remainingDistance / remainingTime;
      } else {
        _targetVelocity = 0.0;
      }
    }

    // 3. Плавное изменение текущей скорости к целевой
    final double smoothingFactor = 1.0 - exp(-_dampingFactor * deltaTimeMs);
    final double velocityDelta = (_targetVelocity - _currentVelocity) * smoothingFactor;
    _currentVelocity += velocityDelta;

    // 4. Проверка выхода на линейный режим
    if (!_isLinearLocked && (_targetVelocity - _currentVelocity).abs() < _velocityTolerance) {
      final double remainingDistance = _phaseTargetPosition - _position;
      final double remainingTime = _targetDurationMs - _elapsedMs;

      if (remainingTime > 0 && remainingDistance > 0) {
        final double correctVelocity = remainingDistance / remainingTime;

        if ((correctVelocity - _currentVelocity).abs() > _velocityTolerance) {
          _currentVelocity = correctVelocity;
          _targetVelocity = correctVelocity;
        }

        _isLinearLocked = true;
      }
    }

    // 5. Обновление позиции
    final double deltaPosition = _currentVelocity * deltaTimeMs;
    _position += deltaPosition;

    // 6. Жёсткий clamp
    if (_position >= 1.0) {
      _position = 1.0;
      _currentVelocity = 0.0;
      _targetVelocity = 0.0;
      _isLinearLocked = false;
    }

    // 7. Уведомление слушателей
    notifyListeners();
  }

  // Очистка ресурсов
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
