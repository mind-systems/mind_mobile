import 'NfbCalibrationData.dart';

/// Base sealed class for all BCI calibration lifecycle events.
///
/// Concrete implementations cover the three outcomes of a calibration run:
/// an individual stage finishing, the overall calibration completing, or a
/// failure. Plugin-level result types (e.g. `IndividualNfbData`) must NOT
/// appear here — conversion is the responsibility of the concrete
/// `IBciDeviceProvider` implementation.
sealed class BciCalibrationEvent {
  const BciCalibrationEvent();
}

/// Emitted when a single calibration stage finishes.
final class BciCalibrationStageFinished extends BciCalibrationEvent {
  final int stage;
  const BciCalibrationStageFinished(this.stage);
}

/// Emitted when the full calibration sequence completes successfully.
///
/// [data] is the domain-level calibration result mapped from the plugin's
/// `IndividualNfbData` by the concrete [IBciDeviceProvider] implementation.
/// Plugin types (e.g. `IndividualNfbData`) must NOT appear in this file —
/// [NfbCalibrationData] is the pure-Dart projection of the calibration outcome.
final class BciCalibrationCompleted extends BciCalibrationEvent {
  final NfbCalibrationData data;
  const BciCalibrationCompleted(this.data);
}

/// Emitted when calibration fails for any reason.
///
/// [reason] is a free-form description. A future refactor may introduce a
/// typed `BciCalibrationFailReason` enum if the UI needs to distinguish
/// failure modes.
final class BciCalibrationFailed extends BciCalibrationEvent {
  final String reason;
  const BciCalibrationFailed(this.reason);
}
