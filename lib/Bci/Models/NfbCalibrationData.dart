import 'package:flutter/foundation.dart';

/// Holds the latest NFB calibration result for SharedPreferences persistence.
///
/// This is a pure-Dart domain projection of the calibration outcome — it is
/// independent of `neiry_kit` types so the domain layer remains decoupled
/// from the hardware plugin.
@immutable
class NfbCalibrationData {
  final DateTime calibratedAt;
  final bool isValid;

  /// Enum-like string describing why calibration failed when [isValid] is false.
  ///
  /// Allowed values:
  /// - `"none"` — calibration succeeded; no failure reason.
  /// - `"tooManyArtifacts"` — signal had too many artifacts to calibrate reliably.
  /// - `"peakFrequencyAtBorder"` — individual peak frequency landed at the edge of
  ///   the analysed band, making the result unreliable.
  final String failReason;

  final double individualFrequency;
  final double individualPeakFrequency;
  final double individualPeakFrequencyPower;
  final double individualPeakFrequencySuppression;
  final double individualBandwidth;
  final double individualNormalizedPower;
  final double lowerFrequency;
  final double upperFrequency;

  const NfbCalibrationData({
    required this.calibratedAt,
    required this.isValid,
    required this.failReason,
    required this.individualFrequency,
    required this.individualPeakFrequency,
    required this.individualPeakFrequencyPower,
    required this.individualPeakFrequencySuppression,
    required this.individualBandwidth,
    required this.individualNormalizedPower,
    required this.lowerFrequency,
    required this.upperFrequency,
  });

  Map<String, dynamic> toJson() {
    return {
      'calibratedAt': calibratedAt.toIso8601String(),
      'isValid': isValid,
      'failReason': failReason,
      'individualFrequency': individualFrequency,
      'individualPeakFrequency': individualPeakFrequency,
      'individualPeakFrequencyPower': individualPeakFrequencyPower,
      'individualPeakFrequencySuppression': individualPeakFrequencySuppression,
      'individualBandwidth': individualBandwidth,
      'individualNormalizedPower': individualNormalizedPower,
      'lowerFrequency': lowerFrequency,
      'upperFrequency': upperFrequency,
    };
  }

  factory NfbCalibrationData.fromJson(Map<String, dynamic> json) {
    return NfbCalibrationData(
      calibratedAt: DateTime.parse(json['calibratedAt'] as String),
      isValid: json['isValid'] as bool,
      failReason: json['failReason'] as String,
      individualFrequency: (json['individualFrequency'] as num).toDouble(),
      individualPeakFrequency: ((json['individualPeakFrequency'] ?? json['individualFrequency']) as num).toDouble(),
      individualPeakFrequencyPower: (json['individualPeakFrequencyPower'] as num).toDouble(),
      individualPeakFrequencySuppression: (json['individualPeakFrequencySuppression'] as num).toDouble(),
      individualBandwidth: (json['individualBandwidth'] as num).toDouble(),
      individualNormalizedPower: (json['individualNormalizedPower'] as num).toDouble(),
      lowerFrequency: (json['lowerFrequency'] as num).toDouble(),
      upperFrequency: (json['upperFrequency'] as num).toDouble(),
    );
  }
}
