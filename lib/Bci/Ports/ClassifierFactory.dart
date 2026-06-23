import 'ClassifierSet.dart';
import 'DevicePort.dart';

/// Narrow port that constructs a [ClassifierSet] from a connected [DevicePort].
///
/// Separates classifier construction from [NeiryBciProvider] so tests can
/// inject a fake without involving vendor types.
///
/// Production default: [NeiryClassifierFactory] (A3).
abstract interface class ClassifierFactory {
  /// Builds the four hardware classifiers from [device] and returns them as a
  /// [ClassifierSet]. The device must be connected before calling this method.
  ClassifierSet build(DevicePort device);
}
