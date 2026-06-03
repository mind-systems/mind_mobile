# NfbCalibrationRepository — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

`NfbCalibrationRepository` manages local calibration history via SharedPreferences and syncs with a remote gRPC API. It stores a per-device list of `NfbCalibrationData` JSON records, enforces a 20-entry limit, and provides queries for full history, the latest valid entry, and record operations.

## Instantiation

Construct with mocked dependencies:

```dart
final prefs = MockSharedPreferences(); // or FakeSharedPreferences
final api = FakeNfbCalibrationGrpcApi();
final repo = NfbCalibrationRepository(prefs: prefs, api: api);
```

**Mocking pattern:** Use `package:shared_preferences` fake or `package:shared_preferences_platform_interface` mock. Mock `NfbCalibrationGrpcApi` with a simple in-memory fake (see _Gotchas_).

## Existing Coverage

None.

## Test Cases

### history(String serial)

- **should return empty list when no key exists for serial**
  - Exercises: `history()` → null from `getString()`
  - Setup: prefs has no entry for `bci_nfb_cal_history_<serial>`
  - Verify: returns `const <NfbCalibrationData>[]`

- **should return empty list when stored value is not valid JSON**
  - Exercises: `history()` → `jsonDecode()` exception path
  - Setup: `setString(_keyFor('abc'), '{invalid json')` 
  - Verify: returns `const <NfbCalibrationData>[]` (catch block)

- **should return empty list when decoded JSON is not a List**
  - Exercises: `history()` → `if (decoded is! List)` branch
  - Setup: `setString(_keyFor('abc'), '{"foo": "bar"}')`
  - Verify: returns `const <NfbCalibrationData>[]`

- **should return single valid entry from JSON array**
  - Exercises: `history()` → `fromJson()` round-trip
  - Setup: encode one `NfbCalibrationData` to JSON array, store in prefs
  - Verify: returns list with one entry, fields match original

- **should return multiple entries preserving order**
  - Exercises: `history()` → array deserialization preserving insertion order
  - Setup: create 5 distinct entries, store as JSON array in prefs
  - Verify: returns list with 5 entries in same order (critical: `record()` prepends, so history order = reverse insertion order)

- **should skip array items that are not Map<String, dynamic>**
  - Exercises: `history()` → `whereType<Map<String, dynamic>>()`
  - Setup: JSON array with mixed types: `[{...valid...}, "string", 123, {...valid...}]`
  - Verify: returns only the two valid maps, skipping scalar items

- **should handle missing optional field with fallback (e.g., individualPeakFrequency)**
  - Exercises: `NfbCalibrationData.fromJson()` null-coalescing in line 67
  - Setup: JSON missing `individualPeakFrequency` key
  - Verify: `individualPeakFrequency` gets value from `individualFrequency`

- **should handle DateTime parsing error gracefully**
  - Exercises: `NfbCalibrationData.fromJson()` → `DateTime.parse()` exception
  - Setup: stored JSON with invalid `calibratedAt` string (e.g., "not-a-date")
  - Verify: exception is caught by `history()`, returns empty list

### latestValid(String serial)

- **should return null when no entries exist**
  - Exercises: `latestValid()` → `history()` returns empty
  - Setup: prefs empty for serial
  - Verify: returns null

- **should return null when all entries have isValid=false**
  - Exercises: `latestValid()` → loop iterates all, none pass `if (entry.isValid)`
  - Setup: store 3 entries, all with `isValid: false`
  - Verify: returns null

- **should return first valid entry encountered in history order**
  - Exercises: `latestValid()` → first-match in descending order (because `record()` prepends)
  - Setup: store 5 entries: invalid, invalid, **valid**, invalid, valid
  - Verify: returns the first valid one (chronologically most recent)

- **should return entry with isValid=true when multiple exist**
  - Exercises: `latestValid()` → correct predicate
  - Setup: store mix of valid and invalid
  - Verify: returns one with `isValid == true`

### refreshFromServer(String serial) [async]

- **should fetch from API and store truncated list when API returns > 20 entries**
  - Exercises: `refreshFromServer()` → API fetch + `sublist(0, 20)` + `setString()`
  - Setup: mock API to return 25 entries
  - Verify: prefs contains JSON with exactly 20 entries, logged no error

- **should fetch and store full list when API returns ≤ 20 entries**
  - Exercises: `refreshFromServer()` → no truncation needed
  - Setup: mock API to return 15 entries
  - Verify: prefs contains all 15, logged no error

- **should log error and not crash when API throws**
  - Exercises: `refreshFromServer()` → catch block
  - Setup: mock API to throw "connection timeout"
  - Verify: caught, `logPrint()` called with error message, no exception propagates

- **should encode entries to JSON via toJson()**
  - Exercises: `refreshFromServer()` → `jsonEncode(trimmed.map((e) => e.toJson()).toList())`
  - Setup: mock API with 1 entry with specific field values
  - Verify: prefs JSON contains those exact field values in ISO8601 format for datetime

- **should store under correct serial key**
  - Exercises: `refreshFromServer()` → `_keyFor(serial)` key
  - Setup: call with serial "ABC123"
  - Verify: prefs key is `bci_nfb_cal_history_ABC123`

- **should overwrite existing cached data**
  - Exercises: `refreshFromServer()` → `setString()` replaces old value
  - Setup: pre-populate prefs with old data, fetch new data from API
  - Verify: old data is gone, new data is present

### record(String serial, NfbCalibrationData data) [async]

- **should prepend new entry to existing history**
  - Exercises: `record()` → `[data, ...existing]`
  - Setup: pre-store 2 entries in history, record a new one
  - Verify: prefs now contains [new, old1, old2], verified via JSON parse

- **should store single entry when history is empty**
  - Exercises: `record()` → history returns empty, `[data, ...]` = `[data]`
  - Setup: empty prefs
  - Verify: prefs contains JSON array with 1 item

- **should truncate to 20 entries when limit exceeded**
  - Exercises: `record()` → `if (newList.length > _maxEntries) newList = newList.sublist(0, 20)`
  - Setup: pre-store 20 entries, record 1 more
  - Verify: prefs contains exactly 20 entries (oldest dropped)

- **should drop old entries when at limit**
  - Exercises: `record()` → index management during truncation
  - Setup: pre-store entries 1–20, record entry 21
  - Verify: entry 1 is dropped, entries 2–21 remain

- **should persist immediately to SharedPreferences (sync)**
  - Exercises: `record()` → `await _prefs.setString()` before unawaited API sync
  - Setup: mock prefs and API
  - Verify: prefs.setString() is awaited; verify via prefs.getString() immediately after
  - Note: API.record() is unawaited, so don't verify it without race condition handling

- **should attempt async API.record() in background (fire-and-forget)**
  - Exercises: `record()` → `unawaited(_api.record(...).catchError(...))`
  - Setup: mock API with slow/failing response
  - Verify: `await record()` completes before API responds (use completer or Future.delayed in mock)

- **should log API error but not crash when sync fails**
  - Exercises: `record()` → `catchError((Object e) => logPrint(...))`
  - Setup: mock API.record() to throw
  - Verify: error logged, test completes, no unhandled exception

- **should encode new list to JSON via toJson()**
  - Exercises: `record()` → `jsonEncode(newList.map((e) => e.toJson()).toList())`
  - Setup: record entry with specific field values
  - Verify: prefs JSON contains those values

- **should use correct serial key**
  - Exercises: `record()` → `_keyFor(serial)`
  - Setup: call with serial "XYZ789"
  - Verify: prefs key is `bci_nfb_cal_history_XYZ789`

- **should handle DateTime serialization round-trip**
  - Exercises: `record()` + `history()` → `toJson()` + `fromJson()` cycle
  - Setup: record entry with specific `calibratedAt`, retrieve history
  - Verify: recovered `calibratedAt` equals original (within parsing tolerance)

## Gotchas

1. **In-memory vs SharedPreferences sync:** `record()` awaits `prefs.setString()` but then fires API sync unawaited. Tests must not assume API sync completes before `record()` returns; verify local cache separately from API behavior.

2. **JSON round-trip DateTime:** `NfbCalibrationData.calibratedAt` is stored as ISO8601 string. `DateTime.parse()` is timezone-aware. Ensure test DateTime values are UTC or use `DateTime.now().toUtc()`.

3. **Ordering invariant:** `history()` returns entries in the order stored in JSON (newest first, since `record()` prepends). Tests relying on "latest" must account for descending timestamp order, not insertion order.

4. **null-coalescing in fromJson:** Line 67 uses `json['individualPeakFrequency'] ?? json['individualFrequency']` as a fallback. Tests should verify both the happy path (field present) and the fallback (field missing or null).

5. **List truncation edge case:** When `newList.length > 20`, truncation uses `sublist(0, 20)`. Verify that last 5 entries are dropped when at capacity, not first 5.

6. **Malformed JSON in prefs:** `history()` catches all exceptions from `jsonDecode()` and `fromJson()`. Tests should verify graceful degradation (empty list) rather than crashes.

7. **whereType filter:** `whereType<Map<String, dynamic>>()` silently skips non-map items in the JSON array. A mixed array `[{...}, "string", null]` will only deserialize the valid object; verify this behavior.

8. **API error logging:** `logPrint()` is called but not awaited. Tests for API errors should mock `logPrint()` or stub it if test framework provides global capture.

## Refactor Required

`record()` fires `_api.record()` with `unawaited(...)`, so calling `await repo.record(...)` in a test returns before the API call completes. Tests asserting server-sync behavior (e.g., "API was called with the correct serial and data") must artificially delay or use a Completer-based mock.

**What to refactor:** Add an optional `@visibleForTesting bool awaitApiSync = false` named parameter to `record()`:

```dart
Future<void> record(
  String serial,
  NfbCalibrationData data, {
  @visibleForTesting bool awaitApiSync = false,
}) async {
  // ... local persist (always awaited) ...
  if (awaitApiSync) {
    await _api.record(serial, data).catchError(...);
  } else {
    unawaited(_api.record(serial, data).catchError(...));
  }
}
```

Production callers pass nothing (default `false`); tests that need to assert API sync behavior pass `awaitApiSync: true`. The local-persist path is already fully testable without this change — only the API-sync assertions need it.
