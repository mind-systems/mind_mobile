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
/// Carries no payload — calibration results from the plugin must not
/// leak into the domain layer.
final class BciCalibrationCompleted extends BciCalibrationEvent {
  const BciCalibrationCompleted();
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
