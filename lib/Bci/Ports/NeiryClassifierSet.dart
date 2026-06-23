import 'package:neiry_kit/neiry_kit.dart' as neiry;

import 'package:mind/Logger.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

import '../Models/BciNfbData.dart';
import '../Models/BciEmotionsData.dart';
import 'ClassifierSet.dart';

/// Thin adapter that wraps the four neiry classifiers and implements [ClassifierSet].
///
/// Builds [neiry.NfbClassifier], [neiry.CardioClassifier],
/// [neiry.EmotionsClassifier], and [neiry.MEMSClassifier] in that order and
/// exposes their output as domain-typed streams. All vendor-to-domain mapping
/// lives here — [NeiryBciProvider] and its subscribers never see neiry types.
///
/// This is one of two files (with [NeiryClassifierFactory]) permitted to
/// import `neiry_kit`.
class NeiryClassifierSet implements ClassifierSet {
  NeiryClassifierSet(neiry.Device device)
      : _nfb = neiry.NfbClassifier(device),
        _cardio = neiry.CardioClassifier(device),
        _emotions = neiry.EmotionsClassifier(device),
        _mems = neiry.MEMSClassifier(device);

  final neiry.NfbClassifier _nfb;
  final neiry.CardioClassifier _cardio;
  final neiry.EmotionsClassifier _emotions;
  final neiry.MEMSClassifier _mems;

  // ── Domain-typed stream getters ─────────────────────────────────────────────

  @override
  Stream<BciNfbData> get nfbStateStream => _nfb.stateStream.map((s) => BciNfbData(
        timestamp: s.timestamp,
        delta: s.delta,
        theta: s.theta,
        alpha: s.alpha,
        smr: s.smr,
        beta: s.beta,
      ));

  @override
  Stream<String> get nfbErrorStream => _nfb.errorStream;

  @override
  Stream<CardioData> get cardioStateStream =>
      _cardio.stateStream.map((c) => CardioData(
            heartRate: c.heartRate,
            metricsAvailable: c.metricsAvailable,
            hasArtifacts: c.hasArtifacts,
            timestamp: c.timestamp,
            source: SensorSource.neiry,
            hrv: null,
          ));

  @override
  Stream<RrInterval> get rrStream => _cardio.rrStream.map((rr) => RrInterval(
        intervalMs: rr.intervalMs,
        timestamp: rr.timestamp,
        isArtifact: rr.isArtifact,
        source: SensorSource.neiry,
      ));

  @override
  Stream<BciEmotionsData> get emotionsStateStream =>
      _emotions.stateStream.map((e) => BciEmotionsData(
            timestamp: e.timestamp,
            attention: e.attention,
            relaxation: e.relaxation,
            cognitiveLoad: e.cognitiveLoad,
            cognitiveControl: e.cognitiveControl,
            selfControl: e.selfControl,
          ));

  @override
  Stream<String> get emotionsErrorStream => _emotions.errorStream;

  @override
  Stream<MotionData> get motionStream => _mems.memsStream.expand(
        (batch) => batch.map((s) => MotionData(
              accelerometer: s.accelerometer,
              gyroscope: s.gyroscope,
              timestamp: s.timestamp,
              source: SensorSource.neiry,
            )),
      );

  // ── dispose ─────────────────────────────────────────────────────────────────

  /// Disposes all four classifiers in order: nfb → cardio → emotions → mems.
  ///
  /// Each dispose is wrapped in its own try/catch so one failure does not skip
  /// the remaining classifiers.
  @override
  Future<void> dispose() async {
    try {
      await _nfb.dispose();
    } catch (e) {
      logPrint('NeiryClassifierSet: nfb dispose error: $e');
    }
    try {
      await _cardio.dispose();
    } catch (e) {
      logPrint('NeiryClassifierSet: cardio dispose error: $e');
    }
    try {
      await _emotions.dispose();
    } catch (e) {
      logPrint('NeiryClassifierSet: emotions dispose error: $e');
    }
    try {
      await _mems.dispose();
    } catch (e) {
      logPrint('NeiryClassifierSet: mems dispose error: $e');
    }
  }
}
