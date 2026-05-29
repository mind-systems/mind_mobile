import 'dart:async';

import 'Models/RrInterval.dart';

/// Capability interface for a source that emits beat-to-beat RR intervals.
///
/// Kept separate from [IHeartRateSource] because some HR sources never expose
/// per-beat intervals — a device that streams only averaged heart rate cannot
/// implement this interface without fabricating data.
abstract interface class IRrIntervalSource {
  Stream<RrInterval> get rrStream;
}
