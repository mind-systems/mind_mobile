import 'dart:async';

import 'Models/CardioData.dart';

/// Capability interface for a source that emits per-sample cardio metrics.
///
/// Implemented by any hardware or software provider that can supply heart rate
/// data — including BCI headbands, Apple Health aggregates, and summary watches.
/// Kept separate from [IRrIntervalSource] because many HR sources do not expose
/// per-beat intervals.
abstract interface class IHeartRateSource {
  Stream<CardioData> get cardioStream;
}
