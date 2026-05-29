import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'Models/CardioData.dart';
import 'Models/MotionData.dart';
import 'Models/RrInterval.dart';

/// Hardware-agnostic biometric sample — a pure data value object.
///
/// Wraps one of five domain types ([CardioData], [RrInterval], [BciNfbData],
/// [BciEmotionsData], [MotionData]) into a uniform `{timestampMs, sampleType, data}`
/// shape consumable by the router/batcher/stream client pipeline.
///
/// No `sessionId` by design — it is injected at wire-encoding time by
/// `BiometricStreamClient.sendBatch`. All timestamps come from SDK per-sample
/// clocks, never from [DateTime.now].
///
/// See: `.ai-factory/notes/28-biometric-stream-pipeline.md` Milestone 5 and
/// `.ai-factory/notes/32-biosample-sdk-timestamps.md`.
final class BioSample {
  final int timestampMs;
  final String sampleType;
  final Map<String, dynamic> data;

  const BioSample({
    required this.timestampMs,
    required this.sampleType,
    required this.data,
  });

  /// Creates a [BioSample] from a [CardioData] measurement.
  ///
  /// Includes the optional `hrv` sub-map only when [CardioData.hrv] is non-null.
  factory BioSample.fromCardio(CardioData cardio) {
    final map = <String, dynamic>{
      'heartRate': cardio.heartRate,
      'metricsAvailable': cardio.metricsAvailable,
      'hasArtifacts': cardio.hasArtifacts,
      'source': cardio.source.name,
    };
    if (cardio.hrv != null) {
      map['hrv'] = <String, dynamic>{
        'rmssd': cardio.hrv!.rmssd,
        'sdnn': cardio.hrv!.sdnn,
        'pnn50': cardio.hrv!.pnn50,
        'lf': cardio.hrv!.lf,
        'hf': cardio.hrv!.hf,
        'lfhf': cardio.hrv!.lfhf,
      };
    }
    return BioSample(
      timestampMs: cardio.timestamp.millisecondsSinceEpoch,
      sampleType: 'cardio',
      data: map,
    );
  }

  /// Creates a [BioSample] from an [RrInterval] measurement.
  ///
  /// Artifacts are forwarded deliberately — the server decides filtering.
  factory BioSample.fromRr(RrInterval rr) => BioSample(
        timestampMs: rr.timestamp.millisecondsSinceEpoch,
        sampleType: 'rr',
        data: <String, dynamic>{
          'intervalMs': rr.intervalMs,
          'isArtifact': rr.isArtifact,
          'source': rr.source.name,
        },
      );

  /// Creates a [BioSample] from a [BciNfbData] measurement.
  ///
  /// Source is hard-coded to `'neiry'` because [BciNfbData] carries no source
  /// field today. When a non-Neiry EEG provider lands, add `source` to the
  /// domain model and read from there.
  factory BioSample.fromNfb(BciNfbData nfb) => BioSample(
        timestampMs: nfb.timestamp.millisecondsSinceEpoch,
        sampleType: 'nfb',
        data: <String, dynamic>{
          'delta': nfb.delta,
          'theta': nfb.theta,
          'alpha': nfb.alpha,
          'smr': nfb.smr,
          'beta': nfb.beta,
          'source': 'neiry',
        },
      );

  /// Creates a [BioSample] from a [BciEmotionsData] measurement.
  ///
  /// Source is hard-coded to `'neiry'` — same rationale as [fromNfb].
  factory BioSample.fromEmotions(BciEmotionsData emotions) => BioSample(
        timestampMs: emotions.timestamp.millisecondsSinceEpoch,
        sampleType: 'emotions',
        data: <String, dynamic>{
          'attention': emotions.attention,
          'relaxation': emotions.relaxation,
          'cognitiveLoad': emotions.cognitiveLoad,
          'cognitiveControl': emotions.cognitiveControl,
          'selfControl': emotions.selfControl,
          'source': 'neiry',
        },
      );

  /// Creates a [BioSample] from a [MotionData] measurement.
  ///
  /// Uses [MotionData.timestamp] (not [DateTime.now]) because MEMS samples
  /// arrive in batches — wall-clock time would collapse the whole batch onto
  /// one instant.
  factory BioSample.fromMotion(MotionData motion) => BioSample(
        timestampMs: motion.timestamp.millisecondsSinceEpoch,
        sampleType: 'motion',
        data: <String, dynamic>{
          'ax': motion.accelerometer.x,
          'ay': motion.accelerometer.y,
          'az': motion.accelerometer.z,
          'gx': motion.gyroscope.x,
          'gy': motion.gyroscope.y,
          'gz': motion.gyroscope.z,
          'source': motion.source.name,
        },
      );
}
