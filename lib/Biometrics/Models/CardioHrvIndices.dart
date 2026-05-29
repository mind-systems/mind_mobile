/// Frequency- and time-domain HRV indices derived from a cardio sample.
///
/// All fields are nullable — a field is `null` when the device has not yet
/// computed that metric or the computation is unavailable for the current
/// sample window.
final class CardioHrvIndices {
  final double? rmssd;
  final double? sdnn;
  final double? pnn50;
  final double? lf;
  final double? hf;
  final double? lfhf;

  const CardioHrvIndices({
    this.rmssd,
    this.sdnn,
    this.pnn50,
    this.lf,
    this.hf,
    this.lfhf,
  });
}
