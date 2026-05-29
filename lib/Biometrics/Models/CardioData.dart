import 'CardioHrvIndices.dart';
import 'SensorSource.dart';

/// A single cardio measurement from a biometric device.
///
/// [timestamp] must originate from the SDK's per-sample clock — do not
/// substitute `DateTime.now()` at the call site.
final class CardioData {
  final double heartRate;
  final bool metricsAvailable;
  final bool hasArtifacts;
  final DateTime timestamp;
  final SensorSource source;
  final CardioHrvIndices? hrv;

  const CardioData({
    required this.heartRate,
    required this.metricsAvailable,
    required this.hasArtifacts,
    required this.timestamp,
    required this.source,
    this.hrv,
  });
}
