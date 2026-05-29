import 'SensorSource.dart';

/// A single motion sample from a biometric device (accelerometer + gyroscope).
///
/// Record fields mirror the SDK's `MemsSample`/`clCPoint3d` triplets.
/// Values are raw device units — normalization happens server-side.
///
/// [timestamp] must originate from the SDK's per-sample clock.
final class MotionData {
  final ({double x, double y, double z}) accelerometer;
  final ({double x, double y, double z}) gyroscope;
  final DateTime timestamp;
  final SensorSource source;

  const MotionData({
    required this.accelerometer,
    required this.gyroscope,
    required this.timestamp,
    required this.source,
  });
}
