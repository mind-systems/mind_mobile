import 'SensorSource.dart';

/// A single beat-to-beat interval measurement.
///
/// Raw substrate from which server-side analytics reconstruct any HRV metric.
/// Firmware-computed indices (e.g. Neiry stress/Kaplan, Garmin body-battery)
/// are deliberately not carried here — those belong at higher layers.
///
/// [timestamp] must originate from the SDK's per-sample clock.
final class RrInterval {
  final int intervalMs;
  final DateTime timestamp;
  final bool isArtifact;
  final SensorSource source;

  const RrInterval({
    required this.intervalMs,
    required this.timestamp,
    required this.isArtifact,
    required this.source,
  });
}
