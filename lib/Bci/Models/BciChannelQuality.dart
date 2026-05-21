import 'package:flutter/foundation.dart';

/// Derived signal-quality bucket for a single EEG channel.
enum BciSignalLevel { green, yellow, red }

/// Carries the current signal quality reading for a single EEG channel.
///
/// [impedanceOhm] is the raw impedance measurement from the device.
/// [level] is a bucketed quality indicator derived from that measurement.
@immutable
class BciChannelQuality {
  final String channelName;
  final double impedanceOhm;
  final BciSignalLevel level;

  const BciChannelQuality({
    required this.channelName,
    required this.impedanceOhm,
    required this.level,
  });
}
