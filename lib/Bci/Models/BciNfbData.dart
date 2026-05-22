import 'package:flutter/foundation.dart';

/// Raw NFB band amplitudes from the device, each normalised to the 0–1 range.
///
/// A field is `null` when no reading has arrived yet for that band.
@immutable
class BciNfbData {
  final double? delta;
  final double? theta;
  final double? alpha;
  final double? smr;
  final double? beta;

  const BciNfbData({
    this.delta,
    this.theta,
    this.alpha,
    this.smr,
    this.beta,
  });
}
