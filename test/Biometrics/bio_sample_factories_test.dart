import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Biometrics/BioSample.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/CardioHrvIndices.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';

void main() {
  // ── Task 1: BioSample.fromCardio ─────────────────────────────────────────

  group('BioSample.fromCardio', () {
    final ts = DateTime(2025, 6, 3, 10, 30, 45, 123);

    test(
      'should set sampleType to cardio and timestampMs from cardio.timestamp.millisecondsSinceEpoch when given a CardioData',
      () {
        final cardio = CardioData(
          heartRate: 72.0,
          metricsAvailable: true,
          hasArtifacts: false,
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromCardio(cardio);
        expect(sample.sampleType, 'cardio');
        expect(sample.timestampMs, ts.millisecondsSinceEpoch);
      },
    );

    test(
      'should encode heartRate, metricsAvailable, hasArtifacts and source.name into data when given a CardioData',
      () {
        final cardio = CardioData(
          heartRate: 68.5,
          metricsAvailable: true,
          hasArtifacts: true,
          timestamp: ts,
          source: SensorSource.garmin,
        );
        final sample = BioSample.fromCardio(cardio);
        expect(sample.data['heartRate'], 68.5);
        expect(sample.data['metricsAvailable'], isTrue);
        expect(sample.data['hasArtifacts'], isTrue);
        expect(sample.data['source'], 'garmin');
      },
    );

    test(
      'should omit the hrv sub-map when cardio.hrv is null',
      () {
        final cardio = CardioData(
          heartRate: 72.0,
          metricsAvailable: true,
          hasArtifacts: false,
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromCardio(cardio);
        expect(sample.data.containsKey('hrv'), isFalse);
      },
    );

    test(
      'should include the full hrv sub-map with all six indices when cardio.hrv is non-null',
      () {
        final hrv = CardioHrvIndices(
          rmssd: 42.0,
          sdnn: 38.5,
          pnn50: 0.25,
          lf: 1200.0,
          hf: 800.0,
          lfhf: 1.5,
        );
        final cardio = CardioData(
          heartRate: 72.0,
          metricsAvailable: true,
          hasArtifacts: false,
          timestamp: ts,
          source: SensorSource.neiry,
          hrv: hrv,
        );
        final sample = BioSample.fromCardio(cardio);
        expect(sample.data['hrv'], isA<Map>());
        final map = sample.data['hrv'] as Map;
        expect(map['rmssd'], 42.0);
        expect(map['sdnn'], 38.5);
        expect(map['pnn50'], 0.25);
        expect(map['lf'], 1200.0);
        expect(map['hf'], 800.0);
        expect(map['lfhf'], 1.5);
      },
    );

    test(
      'should preserve nulls in the hrv sub-map when only some hrv indices are populated',
      () {
        final hrv = CardioHrvIndices(rmssd: 42.0); // all others null
        final cardio = CardioData(
          heartRate: 72.0,
          metricsAvailable: true,
          hasArtifacts: false,
          timestamp: ts,
          source: SensorSource.neiry,
          hrv: hrv,
        );
        final sample = BioSample.fromCardio(cardio);
        final map = sample.data['hrv'] as Map;
        expect(map['rmssd'], 42.0);
        expect(map['sdnn'], isNull);
        expect(map['pnn50'], isNull);
        expect(map['lf'], isNull);
        expect(map['hf'], isNull);
        expect(map['lfhf'], isNull);
      },
    );

    test(
      'should encode each SensorSource value via .name when given that source',
      () {
        for (final src in SensorSource.values) {
          final cardio = CardioData(
            heartRate: 72.0,
            metricsAvailable: true,
            hasArtifacts: false,
            timestamp: ts,
            source: src,
          );
          final sample = BioSample.fromCardio(cardio);
          expect(sample.data['source'], src.name,
              reason: 'Expected ${src.name} for $src');
        }
      },
    );
  });

  // ── Task 2: BioSample.fromRr ──────────────────────────────────────────────

  group('BioSample.fromRr', () {
    final ts = DateTime(2025, 6, 3, 10, 30, 45, 200);

    test(
      'should set sampleType to rr and timestampMs from rr.timestamp.millisecondsSinceEpoch when given an RrInterval',
      () {
        final rr = RrInterval(
          intervalMs: 850,
          timestamp: ts,
          isArtifact: false,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromRr(rr);
        expect(sample.sampleType, 'rr');
        expect(sample.timestampMs, ts.millisecondsSinceEpoch);
      },
    );

    test(
      'should encode intervalMs and source.name into data when given an RrInterval',
      () {
        final rr = RrInterval(
          intervalMs: 920,
          timestamp: ts,
          isArtifact: false,
          source: SensorSource.polar,
        );
        final sample = BioSample.fromRr(rr);
        expect(sample.data['intervalMs'], 920);
        expect(sample.data['source'], 'polar');
      },
    );

    test(
      'should forward isArtifact as false when rr.isArtifact is false',
      () {
        final rr = RrInterval(
          intervalMs: 850,
          timestamp: ts,
          isArtifact: false,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromRr(rr);
        expect(sample.data['isArtifact'], isFalse);
      },
    );

    test(
      'should forward isArtifact as true when rr.isArtifact is true',
      () {
        final rr = RrInterval(
          intervalMs: 850,
          timestamp: ts,
          isArtifact: true,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromRr(rr);
        expect(sample.data['isArtifact'], isTrue);
      },
    );

    test(
      'should encode each SensorSource value via .name when given that source',
      () {
        for (final src in SensorSource.values) {
          final rr = RrInterval(
            intervalMs: 850,
            timestamp: ts,
            isArtifact: false,
            source: src,
          );
          final sample = BioSample.fromRr(rr);
          expect(sample.data['source'], src.name,
              reason: 'Expected ${src.name} for $src');
        }
      },
    );
  });

  // ── Task 3: BioSample.fromNfb ─────────────────────────────────────────────

  group('BioSample.fromNfb', () {
    final ts = DateTime(2025, 6, 3, 10, 30, 45, 300);

    test(
      'should set sampleType to nfb and timestampMs from nfb.timestamp.millisecondsSinceEpoch when given a BciNfbData',
      () {
        final nfb = BciNfbData(timestamp: ts);
        final sample = BioSample.fromNfb(nfb);
        expect(sample.sampleType, 'nfb');
        expect(sample.timestampMs, ts.millisecondsSinceEpoch);
      },
    );

    test(
      'should encode all five band amplitudes (delta, theta, alpha, smr, beta) into data when all bands are present',
      () {
        final nfb = BciNfbData(
          timestamp: ts,
          delta: 0.1,
          theta: 0.2,
          alpha: 0.3,
          smr: 0.4,
          beta: 0.5,
        );
        final sample = BioSample.fromNfb(nfb);
        expect(sample.data['delta'], 0.1);
        expect(sample.data['theta'], 0.2);
        expect(sample.data['alpha'], 0.3);
        expect(sample.data['smr'], 0.4);
        expect(sample.data['beta'], 0.5);
      },
    );

    test(
      'should preserve null band values as null when some bands are unset',
      () {
        final nfb = BciNfbData(timestamp: ts, alpha: 0.5); // others null
        final sample = BioSample.fromNfb(nfb);
        expect(sample.data['delta'], isNull);
        expect(sample.data['theta'], isNull);
        expect(sample.data['alpha'], 0.5);
        expect(sample.data['smr'], isNull);
        expect(sample.data['beta'], isNull);
      },
    );

    test(
      'should hard-code source to neiry regardless of input',
      () {
        final nfb = BciNfbData(timestamp: ts);
        final sample = BioSample.fromNfb(nfb);
        expect(sample.data['source'], 'neiry');
      },
    );
  });

  // ── Task 4: BioSample.fromEmotions ───────────────────────────────────────

  group('BioSample.fromEmotions', () {
    final ts = DateTime(2025, 6, 3, 10, 30, 45, 400);

    test(
      'should set sampleType to emotions and timestampMs from emotions.timestamp.millisecondsSinceEpoch when given a BciEmotionsData',
      () {
        final emotions = BciEmotionsData(timestamp: ts);
        final sample = BioSample.fromEmotions(emotions);
        expect(sample.sampleType, 'emotions');
        expect(sample.timestampMs, ts.millisecondsSinceEpoch);
      },
    );

    test(
      'should encode all five emotion fields (attention, relaxation, cognitiveLoad, cognitiveControl, selfControl) into data when all are present',
      () {
        final emotions = BciEmotionsData(
          timestamp: ts,
          attention: 0.8,
          relaxation: 0.6,
          cognitiveLoad: 0.4,
          cognitiveControl: 0.7,
          selfControl: 0.5,
        );
        final sample = BioSample.fromEmotions(emotions);
        expect(sample.data['attention'], 0.8);
        expect(sample.data['relaxation'], 0.6);
        expect(sample.data['cognitiveLoad'], 0.4);
        expect(sample.data['cognitiveControl'], 0.7);
        expect(sample.data['selfControl'], 0.5);
      },
    );

    test(
      'should preserve null emotion values as null when some fields are unset',
      () {
        final emotions = BciEmotionsData(timestamp: ts, attention: 0.9);
        final sample = BioSample.fromEmotions(emotions);
        expect(sample.data['attention'], 0.9);
        expect(sample.data['relaxation'], isNull);
        expect(sample.data['cognitiveLoad'], isNull);
        expect(sample.data['cognitiveControl'], isNull);
        expect(sample.data['selfControl'], isNull);
      },
    );

    test(
      'should hard-code source to neiry regardless of input',
      () {
        final emotions = BciEmotionsData(timestamp: ts);
        final sample = BioSample.fromEmotions(emotions);
        expect(sample.data['source'], 'neiry');
      },
    );
  });

  // ── Task 5: BioSample.fromMotion ─────────────────────────────────────────

  group('BioSample.fromMotion', () {
    final ts = DateTime(2025, 6, 3, 10, 30, 45, 500);

    test(
      'should set sampleType to motion and timestampMs from motion.timestamp.millisecondsSinceEpoch when given a MotionData',
      () {
        final motion = MotionData(
          accelerometer: (x: 0.0, y: 0.0, z: 0.0),
          gyroscope: (x: 0.0, y: 0.0, z: 0.0),
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromMotion(motion);
        expect(sample.sampleType, 'motion');
        expect(sample.timestampMs, ts.millisecondsSinceEpoch);
      },
    );

    test(
      'should encode the accelerometer triplet into ax, ay, az when given a MotionData',
      () {
        final motion = MotionData(
          accelerometer: (x: 1.1, y: 2.2, z: 3.3),
          gyroscope: (x: 0.0, y: 0.0, z: 0.0),
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromMotion(motion);
        expect(sample.data['ax'], 1.1);
        expect(sample.data['ay'], 2.2);
        expect(sample.data['az'], 3.3);
      },
    );

    test(
      'should encode the gyroscope triplet into gx, gy, gz when given a MotionData',
      () {
        final motion = MotionData(
          accelerometer: (x: 0.0, y: 0.0, z: 0.0),
          gyroscope: (x: 4.4, y: 5.5, z: 6.6),
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromMotion(motion);
        expect(sample.data['gx'], 4.4);
        expect(sample.data['gy'], 5.5);
        expect(sample.data['gz'], 6.6);
      },
    );

    test(
      'should encode source.name (not hard-coded) when given a MotionData',
      () {
        final motion = MotionData(
          accelerometer: (x: 0.0, y: 0.0, z: 0.0),
          gyroscope: (x: 0.0, y: 0.0, z: 0.0),
          timestamp: ts,
          source: SensorSource.garmin,
        );
        final sample = BioSample.fromMotion(motion);
        expect(sample.data['source'], 'garmin');
      },
    );

    test(
      'should preserve negative accelerometer and gyroscope values when given negative inputs',
      () {
        final motion = MotionData(
          accelerometer: (x: -1.5, y: -2.5, z: -3.5),
          gyroscope: (x: -4.5, y: -5.5, z: -6.5),
          timestamp: ts,
          source: SensorSource.neiry,
        );
        final sample = BioSample.fromMotion(motion);
        expect(sample.data['ax'], -1.5);
        expect(sample.data['ay'], -2.5);
        expect(sample.data['az'], -3.5);
        expect(sample.data['gx'], -4.5);
        expect(sample.data['gy'], -5.5);
        expect(sample.data['gz'], -6.5);
      },
    );
  });
}
