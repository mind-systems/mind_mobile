import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind/Bci/NfbCalibrationRepository.dart';
import 'package:mind/Bci/NfbCalibrationGrpcApi.dart';
import 'package:mind/Bci/Models/NfbCalibrationData.dart';

// ---------------------------------------------------------------------------
// Fake API
// ---------------------------------------------------------------------------

class FakeNfbCalibrationGrpcApi implements NfbCalibrationGrpcApi {
  List<NfbCalibrationData> listResult = [];
  Object? listError;
  Object? recordError;

  int recordCallCount = 0;
  String? lastRecordSerial;
  NfbCalibrationData? lastRecordData;

  Completer<void>? _recordCompleter;

  void setRecordDeferred(Completer<void> completer) {
    _recordCompleter = completer;
  }

  @override
  Future<void> record(String serial, NfbCalibrationData data) async {
    recordCallCount++;
    lastRecordSerial = serial;
    lastRecordData = data;
    if (_recordCompleter != null) {
      await _recordCompleter!.future;
    }
    if (recordError != null) throw recordError!;
  }

  @override
  Future<List<NfbCalibrationData>> list(String serial, {int limit = 50}) async {
    if (listError != null) throw listError!;
    return listResult;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NfbCalibrationData _makeEntry({
  DateTime? calibratedAt,
  bool isValid = true,
  double individualFrequency = 10.0,
  double individualPeakFrequency = 10.5,
  double individualPeakFrequencyPower = 1.0,
  double individualPeakFrequencySuppression = 0.5,
  double individualBandwidth = 2.0,
  double individualNormalizedPower = 0.8,
  double lowerFrequency = 8.0,
  double upperFrequency = 12.0,
}) {
  return NfbCalibrationData(
    calibratedAt: calibratedAt ?? DateTime.utc(2024, 1, 1),
    isValid: isValid,
    failReason: isValid ? 'none' : 'tooManyArtifacts',
    individualFrequency: individualFrequency,
    individualPeakFrequency: individualPeakFrequency,
    individualPeakFrequencyPower: individualPeakFrequencyPower,
    individualPeakFrequencySuppression: individualPeakFrequencySuppression,
    individualBandwidth: individualBandwidth,
    individualNormalizedPower: individualNormalizedPower,
    lowerFrequency: lowerFrequency,
    upperFrequency: upperFrequency,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const serial = 'ABC123';
  const key = 'bci_nfb_cal_history_$serial';

  late SharedPreferences prefs;
  late FakeNfbCalibrationGrpcApi api;
  late NfbCalibrationRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = FakeNfbCalibrationGrpcApi();
    repo = NfbCalibrationRepository(prefs: prefs, api: api);
  });

  // -------------------------------------------------------------------------
  // history()
  // -------------------------------------------------------------------------

  group('history()', () {
    test('should return empty list when no key exists for the serial', () {
      expect(repo.history(serial), isEmpty);
    });

    test('should return empty list when stored value is not valid JSON', () async {
      await prefs.setString(key, 'not-valid-json!!!');
      expect(repo.history(serial), isEmpty);
    });

    test('should return empty list when decoded JSON is not a List (e.g. a JSON object)', () async {
      await prefs.setString(key, jsonEncode({'key': 'value'}));
      expect(repo.history(serial), isEmpty);
    });

    test('should return all entries in stored order when JSON array is valid', () async {
      final e1 = _makeEntry(calibratedAt: DateTime.utc(2024, 1, 1));
      final e2 = _makeEntry(calibratedAt: DateTime.utc(2024, 1, 2));
      await prefs.setString(key, jsonEncode([e1.toJson(), e2.toJson()]));

      final result = repo.history(serial);

      expect(result.length, 2);
      expect(result[0].calibratedAt, e1.calibratedAt);
      expect(result[1].calibratedAt, e2.calibratedAt);
    });

    test('should skip array items that are not Map<String, dynamic> (strings, numbers, null)', () async {
      final entry = _makeEntry();
      final raw = jsonEncode(['a-string', 42, null, entry.toJson()]);
      await prefs.setString(key, raw);

      final result = repo.history(serial);

      expect(result.length, 1);
      expect(result[0].calibratedAt, entry.calibratedAt);
    });

    test('should fall back to individualFrequency when individualPeakFrequency key is missing', () async {
      final json = _makeEntry(individualFrequency: 9.5).toJson();
      json.remove('individualPeakFrequency');
      await prefs.setString(key, jsonEncode([json]));

      final result = repo.history(serial);

      expect(result.length, 1);
      expect(result[0].individualPeakFrequency, 9.5);
    });

    test('should return empty list when an entry has an unparseable calibratedAt (exception caught)', () async {
      final json = _makeEntry().toJson();
      json['calibratedAt'] = 'not-a-date';
      await prefs.setString(key, jsonEncode([json]));

      expect(repo.history(serial), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // latestValid()
  // -------------------------------------------------------------------------

  group('latestValid()', () {
    test('should return null when history is empty', () {
      expect(repo.latestValid(serial), isNull);
    });

    test('should return null when every entry has isValid == false', () async {
      final e1 = _makeEntry(isValid: false, calibratedAt: DateTime.utc(2024, 1, 1));
      final e2 = _makeEntry(isValid: false, calibratedAt: DateTime.utc(2024, 1, 2));
      await prefs.setString(key, jsonEncode([e1.toJson(), e2.toJson()]));

      expect(repo.latestValid(serial), isNull);
    });

    test('should return the first valid entry in list order when valids exist among invalids', () async {
      final invalid = _makeEntry(isValid: false, calibratedAt: DateTime.utc(2024, 1, 1));
      final valid = _makeEntry(isValid: true, calibratedAt: DateTime.utc(2024, 1, 2));
      final anotherValid = _makeEntry(isValid: true, calibratedAt: DateTime.utc(2024, 1, 3));
      await prefs.setString(
        key,
        jsonEncode([invalid.toJson(), valid.toJson(), anotherValid.toJson()]),
      );

      final result = repo.latestValid(serial);

      expect(result, isNotNull);
      expect(result!.calibratedAt, valid.calibratedAt);
    });

    test('should return the first list entry when it is already valid', () async {
      final v = _makeEntry(isValid: true, calibratedAt: DateTime.utc(2024, 6, 1));
      await prefs.setString(key, jsonEncode([v.toJson()]));

      final result = repo.latestValid(serial);

      expect(result, isNotNull);
      expect(result!.calibratedAt, v.calibratedAt);
    });
  });

  // -------------------------------------------------------------------------
  // record() — local persistence
  // -------------------------------------------------------------------------

  group('record() — local persistence', () {
    test('should store a single-element array when history was empty', () async {
      final entry = _makeEntry();

      await repo.record(serial, entry);

      expect(repo.history(serial).length, 1);
    });

    test('should prepend the new entry ahead of existing entries', () async {
      final old = _makeEntry(calibratedAt: DateTime.utc(2024, 1, 1));
      await prefs.setString(key, jsonEncode([old.toJson()]));

      final newer = _makeEntry(calibratedAt: DateTime.utc(2024, 6, 1));
      await repo.record(serial, newer);

      final result = repo.history(serial);
      expect(result[0].calibratedAt, newer.calibratedAt);
      expect(result[1].calibratedAt, old.calibratedAt);
    });

    test('should truncate to 20 entries (dropping the oldest) when the limit is exceeded', () async {
      final existing = List.generate(
        20,
        (i) => _makeEntry(calibratedAt: DateTime.utc(2024, 1, i + 1)),
      );
      await prefs.setString(
        key,
        jsonEncode(existing.map((e) => e.toJson()).toList()),
      );

      final newest = _makeEntry(calibratedAt: DateTime.utc(2024, 12, 31));
      await repo.record(serial, newest);

      final result = repo.history(serial);
      expect(result.length, 20);
      expect(result.first.calibratedAt, newest.calibratedAt);
      // existing[19] (Jan 20) is dropped; existing[18] (Jan 19) is the tail
      expect(result.last.calibratedAt, existing[18].calibratedAt);
    });

    test('should persist under the correct serial key (bci_nfb_cal_history_<serial>)', () async {
      const otherSerial = 'XYZ999';
      final entry = _makeEntry();

      await repo.record(serial, entry);

      expect(prefs.getString('bci_nfb_cal_history_$serial'), isNotNull);
      expect(prefs.getString('bci_nfb_cal_history_$otherSerial'), isNull);
    });

    test('should round-trip via history() so the recorded entry is read back with matching fields', () async {
      final entry = _makeEntry(
        calibratedAt: DateTime.utc(2024, 3, 15, 10, 30),
        isValid: true,
        individualFrequency: 9.8,
        individualPeakFrequency: 10.2,
        lowerFrequency: 8.5,
        upperFrequency: 11.5,
      );

      await repo.record(serial, entry);

      final result = repo.history(serial);
      expect(result.length, 1);
      final rt = result[0];
      expect(rt.calibratedAt, entry.calibratedAt);
      expect(rt.isValid, entry.isValid);
      expect(rt.individualFrequency, entry.individualFrequency);
      expect(rt.individualPeakFrequency, entry.individualPeakFrequency);
      expect(rt.lowerFrequency, entry.lowerFrequency);
      expect(rt.upperFrequency, entry.upperFrequency);
    });
  });

  // -------------------------------------------------------------------------
  // record() — API sync behavior
  // -------------------------------------------------------------------------

  group('record() — API sync behavior', () {
    test('should call api.record with the same serial and data when awaitApiSync is true', () async {
      final entry = _makeEntry();

      await repo.record(serial, entry, awaitApiSync: true);

      expect(api.recordCallCount, 1);
      expect(api.lastRecordSerial, serial);
      expect(api.lastRecordData, entry);
    });

    test('should persist locally and return before the API completes when awaitApiSync is false (fire-and-forget)', () async {
      final completer = Completer<void>();
      api.setRecordDeferred(completer);
      final entry = _makeEntry();

      // Returns immediately — does not wait for the deferred API future
      await repo.record(serial, entry, awaitApiSync: false);

      // Local persistence is already done
      expect(repo.history(serial).length, 1);
      // API call was initiated (counter incremented synchronously)
      expect(api.recordCallCount, 1);

      // Clean up dangling future
      completer.complete();
    });

    test('should still persist locally and not rethrow when the API record fails (awaitApiSync: true)', () async {
      api.recordError = Exception('network error');
      final entry = _makeEntry();

      await expectLater(
        repo.record(serial, entry, awaitApiSync: true),
        completes,
      );

      // Local persistence was written before the API error
      expect(repo.history(serial).length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // refreshFromServer()
  // -------------------------------------------------------------------------

  group('refreshFromServer()', () {
    test('should store all entries when the API returns 20 or fewer', () async {
      api.listResult = List.generate(
        15,
        (i) => _makeEntry(calibratedAt: DateTime.utc(2024, 1, i + 1)),
      );

      await repo.refreshFromServer(serial);

      expect(repo.history(serial).length, 15);
    });

    test('should truncate to 20 entries when the API returns more than 20', () async {
      api.listResult = List.generate(
        25,
        (i) => _makeEntry(calibratedAt: DateTime.utc(2024, 1, i + 1)),
      );

      await repo.refreshFromServer(serial);

      expect(repo.history(serial).length, 20);
    });

    test('should overwrite previously cached data for the serial', () async {
      final old = _makeEntry(calibratedAt: DateTime.utc(2020, 1, 1));
      await prefs.setString(key, jsonEncode([old.toJson()]));

      api.listResult = [_makeEntry(calibratedAt: DateTime.utc(2024, 6, 1))];

      await repo.refreshFromServer(serial);

      final result = repo.history(serial);
      expect(result.length, 1);
      expect(result[0].calibratedAt, DateTime.utc(2024, 6, 1));
    });

    test('should write entries readable by history() with matching field values', () async {
      final entry = _makeEntry(
        calibratedAt: DateTime.utc(2024, 5, 20, 8, 0),
        isValid: false,
        individualFrequency: 11.1,
        individualPeakFrequency: 11.3,
      );
      api.listResult = [entry];

      await repo.refreshFromServer(serial);

      final result = repo.history(serial);
      expect(result.length, 1);
      expect(result[0].calibratedAt, entry.calibratedAt);
      expect(result[0].isValid, entry.isValid);
      expect(result[0].individualFrequency, entry.individualFrequency);
      expect(result[0].individualPeakFrequency, entry.individualPeakFrequency);
    });

    test('should leave the cache unchanged and not rethrow when the API list call throws', () async {
      final existing = _makeEntry(calibratedAt: DateTime.utc(2024, 1, 1));
      await prefs.setString(key, jsonEncode([existing.toJson()]));

      api.listError = Exception('server error');

      await expectLater(repo.refreshFromServer(serial), completes);

      final result = repo.history(serial);
      expect(result.length, 1);
      expect(result[0].calibratedAt, existing.calibratedAt);
    });
  });
}
