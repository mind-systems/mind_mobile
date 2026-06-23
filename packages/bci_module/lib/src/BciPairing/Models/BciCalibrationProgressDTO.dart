class BciCalibrationProgressDTO {
  final int stagesCompleted;
  final bool isComplete;

  /// Total number of stages in the current run — 4 for a full calibration,
  /// 1 for a quick retry.
  final int totalStages;

  /// True when the calibration completed but the result was invalid.
  final bool failed;

  /// Machine-readable failure code when [failed] is true, e.g.
  /// `"tooManyArtifacts"` or `"peakFrequencyAtBorder"`. Null when not failed.
  final String? failReason;

  const BciCalibrationProgressDTO({
    required this.stagesCompleted,
    required this.isComplete,
    required this.totalStages,
    required this.failed,
    this.failReason,
  });
}
