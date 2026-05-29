import 'dart:async';

import 'Models/MotionData.dart';

/// Capability interface for a source that emits per-sample motion data.
///
/// Each emission represents one sample — the provider is responsible for
/// unrolling SDK batches into individual per-sample emissions before adding
/// them to this stream.
abstract interface class IMotionSource {
  Stream<MotionData> get motionStream;
}
