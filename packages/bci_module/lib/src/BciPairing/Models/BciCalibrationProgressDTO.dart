/// Snapshot of calibration progress emitted by the BCI pairing service.
///
/// `stagesCompleted` is in the range 0–4 (one entry per stage emitted by
/// domain `BciCalibrationStageFinished`).
///
/// `isComplete` corresponds to domain `BciCalibrationCompleted` and is
/// authoritative; it MAY be `true` while `stagesCompleted < 4` if the domain
/// emits completion early. Consumers should treat `isComplete` as the terminal
/// signal — do not infer completion from `stagesCompleted == 4` alone.
class BciCalibrationProgressDTO {
  final int stagesCompleted;
  final bool isComplete;

  const BciCalibrationProgressDTO({
    required this.stagesCompleted,
    required this.isComplete,
  });
}
