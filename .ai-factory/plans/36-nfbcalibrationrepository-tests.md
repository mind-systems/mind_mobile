# Test Plan: NfbCalibrationRepository tests

## Context
`NfbCalibrationRepository` (`lib/Bci/NfbCalibrationRepository.dart`) caches per-device NFB calibration history in `SharedPreferences` (key `bci_nfb_cal_history_<serial>`, capped at 20 entries) and syncs with a remote gRPC API. No tests exist; this plan covers `history()`, `latestValid()`, `record()`, and `refreshFromServer()`.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Bci/nfb_calibration_repository_test.dart`

## Target Spec File
`test/Bci/nfb_calibration_repository_test.dart`

## Test Infrastructure (shared setup — implementer wires this)
- Call `TestWidgetsFlutterBinding.ensureInitialized()` and `SharedPreferences.setMockInitialValues({})` in `setUp`, then obtain the instance via `await SharedPreferences.getInstance()`.
- Implement a `FakeNfbCalibrationGrpcApi implements NfbCalibrationGrpcApi` with configurable behavior: a `List<NfbCalibrationData> listResult` (returned by `list()`), optional `Object? listError` / `Object? recordError` to throw, and capture of `record()` calls (serial + data) plus a call counter. Support a deferrable `record()` (e.g. backed by a `Completer`) so fire-and-forget vs awaited paths can be distinguished.
- Add a `NfbCalibrationData` factory helper that builds entries with overridable `calibratedAt`, `isValid`, and numeric fields, using UTC timestamps.
- Seed prefs directly via `prefs.setString(_keyFor(serial), ...)` where `_keyFor(serial)` = `'bci_nfb_cal_history_$serial'`.

## Tasks

### Phase 1: NfbCalibrationRepository — history()

- [x] **Task 1: `history()` read and decode behavior**
  Files: `test/Bci/nfb_calibration_repository_test.dart`
  Test cases:
  - `should return empty list when no key exists for the serial`
  - `should return empty list when stored value is not valid JSON`
  - `should return empty list when decoded JSON is not a List (e.g. a JSON object)`
  - `should return all entries in stored order when JSON array is valid`
  - `should skip array items that are not Map<String, dynamic> (strings, numbers, null)`
  - `should fall back to individualFrequency when individualPeakFrequency key is missing`
  - `should return empty list when an entry has an unparseable calibratedAt (exception caught)`

### Phase 2: NfbCalibrationRepository — latestValid()

- [x] **Task 2: `latestValid()` selection logic**
  Files: `test/Bci/nfb_calibration_repository_test.dart`
  Test cases:
  - `should return null when history is empty`
  - `should return null when every entry has isValid == false`
  - `should return the first valid entry in list order when valids exist among invalids`
  - `should return the first list entry when it is already valid`

### Phase 3: NfbCalibrationRepository — record()

- [x] **Task 3: `record()` local persistence and ordering**
  Files: `test/Bci/nfb_calibration_repository_test.dart`
  Test cases:
  - `should store a single-element array when history was empty`
  - `should prepend the new entry ahead of existing entries`
  - `should truncate to 20 entries (dropping the oldest) when the limit is exceeded`
  - `should persist under the correct serial key (bci_nfb_cal_history_<serial>)`
  - `should round-trip via history() so the recorded entry is read back with matching fields`

- [x] **Task 4: `record()` API sync behavior**
  Files: `test/Bci/nfb_calibration_repository_test.dart`
  Test cases:
  - `should call api.record with the same serial and data when awaitApiSync is true`
  - `should persist locally and return before the API completes when awaitApiSync is false (fire-and-forget)`
  - `should still persist locally and not rethrow when the API record fails (awaitApiSync: true)`

### Phase 4: NfbCalibrationRepository — refreshFromServer()

- [x] **Task 5: `refreshFromServer()` cache replacement**
  Files: `test/Bci/nfb_calibration_repository_test.dart`
  Test cases:
  - `should store all entries when the API returns 20 or fewer`
  - `should truncate to 20 entries when the API returns more than 20`
  - `should overwrite previously cached data for the serial`
  - `should write entries readable by history() with matching field values`
  - `should leave the cache unchanged and not rethrow when the API list call throws`
