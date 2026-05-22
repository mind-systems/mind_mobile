import 'package:flutter/foundation.dart';

/// High-level emotion classifier outputs, mapped from `EmotionsStates`.
///
/// Each field is normalised to the 0–1 range and is `null` when unavailable.
@immutable
class BciEmotionsData {
  final double? attention;
  final double? relaxation;
  final double? cognitiveLoad;
  final double? cognitiveControl;
  final double? selfControl;

  const BciEmotionsData({
    this.attention,
    this.relaxation,
    this.cognitiveLoad,
    this.cognitiveControl,
    this.selfControl,
  });
}
