import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mind/Logger.dart';

class BreathMotionEngine extends ChangeNotifier {
  double _rawPosition = 0.0;
  double _smoothedIntervalMs = 1000.0;
  int _remainingTicks = 0;
  bool _isActive = false;
  bool _isFirstInterval = true;

  static const double _smoothingFactor = 0.2;
  static const double _maxSpeedPerMs = 0.01; // 1.0 за 100ms минимум
  static const double _fallbackSpeed = 0.0001;

  late final Ticker _ticker;
  Duration? _previousElapsed;

  BreathMotionEngine(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  double get normalizedPosition => _rawPosition.clamp(0.0, 1.0);
  bool get isActive => _isActive;

  void setActive(bool active) {
    _isActive = active;
    if (_isActive && !_ticker.isActive) {
      _previousElapsed = null;
      _ticker.start();
    } else if (!_isActive && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void setRemainingTicks(int ticks) {
    _remainingTicks = ticks < 0 ? 0 : ticks;
  }

  void setIntervalMs(int intervalMs) {
    if (intervalMs <= 0) return;

    if (_isFirstInterval) {
      _smoothedIntervalMs = intervalMs.toDouble();
      _isFirstInterval = false;
    } else {
      _smoothedIntervalMs = _smoothedIntervalMs + _smoothingFactor * (intervalMs.toDouble() - _smoothedIntervalMs);
    }
  }

  void resetPosition([double newPosition = 0.0]) {
    _rawPosition = newPosition;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    if (_previousElapsed == null) {
      _previousElapsed = elapsed;
      return;
    }

    final double deltaTimeMs =
        (elapsed - _previousElapsed!).inMicroseconds / 1000.0;
    _previousElapsed = elapsed;

    if (!_isActive) return;

    final double remainingTimeMs = _remainingTicks * _smoothedIntervalMs;

    double speed;
    if (remainingTimeMs <= 0) {
      speed = _fallbackSpeed;
    } else {
      final double remainingDistance = 1.0 - _rawPosition;
      speed = remainingDistance / remainingTimeMs;

      if (speed > _maxSpeedPerMs) {
        speed = _maxSpeedPerMs;
      }
    }

    _rawPosition += speed * deltaTimeMs;

    if (_rawPosition > 1.0) {
      _rawPosition = 1.0;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
