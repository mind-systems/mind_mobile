import 'package:neiry_kit/neiry_kit.dart' as neiry;

import '../Models/NfbCalibrationData.dart';

/// Bidirectional mapper between [NfbCalibrationData] and [neiry.IndividualNfbData].
///
/// This is one of the files permitted to import `neiry_kit` (alongside
/// [NeiryLocatorAdapter], [NeiryDeviceAdapter], and [NeiryClassifierSet]).
/// It is the single home of the [NfbCalibrationData] ↔ [neiry.IndividualNfbData]
/// field mapping — all 11 fields are carried in each direction.
class NeiryCalibrationMapper {
  NeiryCalibrationMapper._();

  /// Maps a [neiry.IndividualNfbData] received from the SDK to a domain
  /// [NfbCalibrationData].
  ///
  /// Uses `DateTime.now()` as a fallback when [data.timestamp] is null.
  static NfbCalibrationData fromNeiry(neiry.IndividualNfbData data) {
    return NfbCalibrationData(
      calibratedAt: data.timestamp ?? DateTime.now(),
      isValid: data.isValid,
      failReason: data.failReason.name,
      individualFrequency: data.individualFrequency,
      individualPeakFrequency: data.individualPeakFrequency,
      individualPeakFrequencyPower: data.individualPeakFrequencyPower,
      individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
      individualBandwidth: data.individualBandwidth,
      individualNormalizedPower: data.individualNormalizedPower,
      lowerFrequency: data.lowerFrequency,
      upperFrequency: data.upperFrequency,
    );
  }

  /// Maps a domain [NfbCalibrationData] to a [neiry.IndividualNfbData] for
  /// import back into the SDK.
  ///
  /// Throws a [StateError] if [data.failReason] does not match any
  /// [neiry.NfbCalibrationFailReason] enum value name — preserving the
  /// current throw-on-unknown behaviour.
  ///
  /// Note: [neiry.IndividualNfbData] derives `isValid` from `failReason`
  /// internally, so it is not passed explicitly.
  static neiry.IndividualNfbData toNeiry(NfbCalibrationData data) {
    return neiry.IndividualNfbData(
      timestamp: data.calibratedAt,
      failReason: neiry.NfbCalibrationFailReason.values
          .firstWhere((e) => e.name == data.failReason),
      individualFrequency: data.individualFrequency,
      individualPeakFrequency: data.individualPeakFrequency,
      individualPeakFrequencyPower: data.individualPeakFrequencyPower,
      individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
      individualBandwidth: data.individualBandwidth,
      individualNormalizedPower: data.individualNormalizedPower,
      lowerFrequency: data.lowerFrequency,
      upperFrequency: data.upperFrequency,
    );
  }
}
