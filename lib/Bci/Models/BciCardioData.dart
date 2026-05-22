import 'package:flutter/foundation.dart';

/// Cardio metrics received from the device.
///
/// [metricsAvailable] and [hasArtifacts] are transport flags; consumers gate
/// valid readings via `metricsAvailable && !hasArtifacts`.
@immutable
class BciCardioData {
  final double heartRate;
  final bool metricsAvailable;
  final bool hasArtifacts;

  const BciCardioData({
    required this.heartRate,
    required this.metricsAvailable,
    required this.hasArtifacts,
  });
}
