import '../Models/BciNfbData.dart';
import '../Models/BciEmotionsData.dart';
import '../../Biometrics/Models/CardioData.dart';
import '../../Biometrics/Models/RrInterval.dart';
import '../../Biometrics/Models/MotionData.dart';

/// Narrow port over the four hardware classifiers that [NeiryBciProvider] consumes.
///
/// Exposes the seven domain-typed streams produced by NFB, Cardio, Emotions,
/// and MEMS classifiers. A fake can implement this interface without depending
/// on `neiry_kit`.
///
/// Concrete implementation: [NeiryClassifierSet] (A3).
abstract interface class ClassifierSet {
  /// NFB band amplitudes from the NFB classifier's state stream.
  Stream<BciNfbData> get nfbStateStream;

  /// Classifier-level error messages from the NFB classifier.
  Stream<String> get nfbErrorStream;

  /// Heart-rate and artifact flag from the Cardio classifier.
  Stream<CardioData> get cardioStateStream;

  /// Beat-to-beat RR intervals from the Cardio classifier.
  Stream<RrInterval> get rrStream;

  /// Emotion band amplitudes from the Emotions classifier.
  Stream<BciEmotionsData> get emotionsStateStream;

  /// Classifier-level error messages from the Emotions classifier.
  Stream<String> get emotionsErrorStream;

  /// Per-sample motion data fanned out from the MEMS classifier's batch stream.
  Stream<MotionData> get motionStream;

  /// Disposes all four classifiers. May throw if any classifier fails.
  Future<void> dispose();
}
