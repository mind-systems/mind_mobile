import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Biometrics/SmoothedRrSource.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';
import 'package:mind/BreathModule/TickCadence/ITickCadenceSource.dart';

// ---------------------------------------------------------------------------
// FakeSmoothedRrSource
// ---------------------------------------------------------------------------

/// Shared test double for [SmoothedRrSource].
///
/// Extracted from [heart_rate_tick_service_test.dart] so both
/// [rr_tick_cadence_source_test.dart] and the heart-rate test can import it.
class FakeSmoothedRrSource implements SmoothedRrSource {
  final _smoothedSubject = BehaviorSubject<int>();
  final _hasActiveSubject = BehaviorSubject<bool>.seeded(false);

  @override
  bool hasActiveSource = false;

  @override
  int? smoothedIntervalMs;

  /// Emit a smoothed interval without touching [smoothedIntervalMs].
  void emitSmoothed(int ms) {
    smoothedIntervalMs = ms;
    _smoothedSubject.add(ms);
  }

  /// Seed the BehaviorSubject so new subscribers receive a replay immediately.
  void seedSmoothed(int ms) {
    smoothedIntervalMs = ms;
    _smoothedSubject.add(ms);
  }

  void emitHasActive(bool value) {
    hasActiveSource = value;
    _hasActiveSubject.add(value);
  }

  @override
  Stream<int> get smoothedIntervalStream => _smoothedSubject.stream;

  @override
  Stream<bool> get hasActiveSourceStream => _hasActiveSubject.stream;

  Future<void> close() async {
    await _smoothedSubject.close();
    await _hasActiveSubject.close();
  }

  @override
  Future<void> dispose() async => close();
}

// ---------------------------------------------------------------------------
// FakeTickCadenceSource
// ---------------------------------------------------------------------------

/// Shared test double for [ITickCadenceSource].
///
/// Used by [heart_rate_tick_service_test.dart] to drive [HeartRateTickService]
/// without any staleness or grace logic — only the metronome is under test there.
class FakeTickCadenceSource implements ITickCadenceSource {
  FakeTickCadenceSource({this.currentPeriodMs, bool initialIsUsable = false}) {
    _usableSubject = BehaviorSubject<bool>.seeded(initialIsUsable);
  }

  @override
  int? currentPeriodMs;

  late final BehaviorSubject<bool> _usableSubject;
  final _periodController = StreamController<int>.broadcast();

  bool disposed = false;

  @override
  bool get isUsable => _usableSubject.value;

  /// Emit a period update on [smoothedPeriodMs].
  /// No-op if the controller is already closed (e.g. after dispose()).
  void emitPeriod(int ms) {
    if (!_periodController.isClosed) _periodController.add(ms);
  }

  /// Flip [isUsable] and emit on [usableChanges] (no-op if value unchanged).
  void setUsable(bool value) {
    if (!_usableSubject.isClosed && _usableSubject.value != value) {
      _usableSubject.add(value);
    }
  }

  @override
  Stream<int> get smoothedPeriodMs => _periodController.stream;

  @override
  Stream<bool> get usableChanges => _usableSubject.stream;

  @override
  void dispose() {
    disposed = true;
    if (!_periodController.isClosed) _periodController.close();
    if (!_usableSubject.isClosed) _usableSubject.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convenience constructor for [RrInterval] values in tests.
RrInterval rr(int intervalMs, {bool isArtifact = false}) => RrInterval(
      intervalMs: intervalMs,
      timestamp: DateTime(2026, 1, 1),
      isArtifact: isArtifact,
      source: SensorSource.neiry,
    );
