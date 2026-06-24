import 'package:flutter_test/flutter_test.dart';
import 'package:neiry_kit/neiry_kit.dart' as neiry;

import 'package:mind/Bci/Models/NfbCalibrationData.dart';
import 'package:mind/Bci/Ports/NeiryCalibrationMapper.dart';

void main() {
  // -------------------------------------------------------------------------
  // Round-trip: fromNeiry then toNeiry preserves all 11 fields
  // -------------------------------------------------------------------------

  group('round-trip — fromNeiry → toNeiry preserves all 11 fields', () {
    test('fromNeiry maps all 11 fields correctly', () {
      final ts = DateTime.utc(2024, 6, 15, 12, 0, 0);
      final sdk = neiry.IndividualNfbData(
        timestamp: ts,
        failReason: neiry.NfbCalibrationFailReason.none,
        individualFrequency: 10.1,
        individualPeakFrequency: 10.5,
        individualPeakFrequencyPower: 2.2,
        individualPeakFrequencySuppression: 0.4,
        individualBandwidth: 3.3,
        individualNormalizedPower: 0.75,
        lowerFrequency: 8.0,
        upperFrequency: 12.5,
      );

      final domain = NeiryCalibrationMapper.fromNeiry(sdk);

      expect(domain.calibratedAt, ts);
      expect(domain.isValid, sdk.isValid);
      expect(domain.failReason, 'none');
      expect(domain.individualFrequency, 10.1);
      expect(domain.individualPeakFrequency, 10.5);
      expect(domain.individualPeakFrequencyPower, 2.2);
      expect(domain.individualPeakFrequencySuppression, 0.4);
      expect(domain.individualBandwidth, 3.3);
      expect(domain.individualNormalizedPower, 0.75);
      expect(domain.lowerFrequency, 8.0);
      expect(domain.upperFrequency, 12.5);
    });

    test('toNeiry maps all 11 fields correctly', () {
      final ts = DateTime.utc(2024, 6, 15, 12, 0, 0);
      final domain = NfbCalibrationData(
        calibratedAt: ts,
        isValid: true,
        failReason: 'none',
        individualFrequency: 10.1,
        individualPeakFrequency: 10.5,
        individualPeakFrequencyPower: 2.2,
        individualPeakFrequencySuppression: 0.4,
        individualBandwidth: 3.3,
        individualNormalizedPower: 0.75,
        lowerFrequency: 8.0,
        upperFrequency: 12.5,
      );

      final sdk = NeiryCalibrationMapper.toNeiry(domain);

      expect(sdk.timestamp, ts);
      expect(sdk.failReason, neiry.NfbCalibrationFailReason.none);
      expect(sdk.individualFrequency, 10.1);
      expect(sdk.individualPeakFrequency, 10.5);
      expect(sdk.individualPeakFrequencyPower, 2.2);
      expect(sdk.individualPeakFrequencySuppression, 0.4);
      expect(sdk.individualBandwidth, 3.3);
      expect(sdk.individualNormalizedPower, 0.75);
      expect(sdk.lowerFrequency, 8.0);
      expect(sdk.upperFrequency, 12.5);
    });

    test('fromNeiry then toNeiry yields equivalent SDK object for all numeric fields and timestamp', () {
      final ts = DateTime.utc(2024, 3, 10, 8, 30);
      final original = neiry.IndividualNfbData(
        timestamp: ts,
        failReason: neiry.NfbCalibrationFailReason.tooManyArtifacts,
        individualFrequency: 9.7,
        individualPeakFrequency: 9.9,
        individualPeakFrequencyPower: 1.8,
        individualPeakFrequencySuppression: 0.3,
        individualBandwidth: 2.5,
        individualNormalizedPower: 0.6,
        lowerFrequency: 7.5,
        upperFrequency: 11.0,
      );

      final roundTripped = NeiryCalibrationMapper.toNeiry(
        NeiryCalibrationMapper.fromNeiry(original),
      );

      expect(roundTripped.timestamp, original.timestamp);
      expect(roundTripped.failReason, original.failReason);
      expect(roundTripped.individualFrequency, original.individualFrequency);
      expect(roundTripped.individualPeakFrequency, original.individualPeakFrequency);
      expect(roundTripped.individualPeakFrequencyPower, original.individualPeakFrequencyPower);
      expect(roundTripped.individualPeakFrequencySuppression, original.individualPeakFrequencySuppression);
      expect(roundTripped.individualBandwidth, original.individualBandwidth);
      expect(roundTripped.individualNormalizedPower, original.individualNormalizedPower);
      expect(roundTripped.lowerFrequency, original.lowerFrequency);
      expect(roundTripped.upperFrequency, original.upperFrequency);
    });
  });

  // -------------------------------------------------------------------------
  // failReason mapping for every enum value
  // -------------------------------------------------------------------------

  group('failReason mapping — all enum values', () {
    for (final entry in [
      (neiry.NfbCalibrationFailReason.none, 'none'),
      (neiry.NfbCalibrationFailReason.tooManyArtifacts, 'tooManyArtifacts'),
      (neiry.NfbCalibrationFailReason.peakFrequencyAtBorder, 'peakFrequencyAtBorder'),
    ]) {
      final enumValue = entry.$1;
      final name = entry.$2;

      test('fromNeiry: ${enumValue.name} → "$name"', () {
        final sdk = neiry.IndividualNfbData(
          failReason: enumValue,
          timestamp: DateTime.utc(2024, 1, 1),
        );
        final domain = NeiryCalibrationMapper.fromNeiry(sdk);
        expect(domain.failReason, name);
      });

      test('toNeiry: "$name" → ${enumValue.name}', () {
        final domain = NfbCalibrationData(
          calibratedAt: DateTime.utc(2024, 1, 1),
          isValid: enumValue == neiry.NfbCalibrationFailReason.none,
          failReason: name,
          individualFrequency: 10.0,
          individualPeakFrequency: 10.0,
          individualPeakFrequencyPower: 1.0,
          individualPeakFrequencySuppression: 0.5,
          individualBandwidth: 2.0,
          individualNormalizedPower: 0.8,
          lowerFrequency: 8.0,
          upperFrequency: 12.0,
        );
        final sdk = NeiryCalibrationMapper.toNeiry(domain);
        expect(sdk.failReason, enumValue);
      });
    }
  });

  // -------------------------------------------------------------------------
  // null-timestamp fallback
  // -------------------------------------------------------------------------

  group('null-timestamp fallback', () {
    test('fromNeiry yields non-null calibratedAt when SDK timestamp is null', () {
      final sdk = neiry.IndividualNfbData(
        timestamp: null,
        failReason: neiry.NfbCalibrationFailReason.none,
      );

      final before = DateTime.now();
      final domain = NeiryCalibrationMapper.fromNeiry(sdk);
      final after = DateTime.now();

      expect(domain.calibratedAt, isNotNull);
      expect(
        domain.calibratedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        domain.calibratedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // unknown failReason throws
  // -------------------------------------------------------------------------

  group('unknown failReason throws', () {
    test('toNeiry throws StateError when failReason is not a known enum name', () {
      final domain = NfbCalibrationData(
        calibratedAt: DateTime.utc(2024, 1, 1),
        isValid: false,
        failReason: 'unknownValue',
        individualFrequency: 10.0,
        individualPeakFrequency: 10.0,
        individualPeakFrequencyPower: 1.0,
        individualPeakFrequencySuppression: 0.5,
        individualBandwidth: 2.0,
        individualNormalizedPower: 0.8,
        lowerFrequency: 8.0,
        upperFrequency: 12.0,
      );

      expect(() => NeiryCalibrationMapper.toNeiry(domain), throwsStateError);
    });
  });
}
