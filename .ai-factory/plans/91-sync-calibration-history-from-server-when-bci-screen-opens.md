# Plan: Sync calibration history from server when BCI screen opens

## Context
Lazy-sync the per-serial NFB calibration history from the server when the BCI screen triggers a scan. The server is the source of truth for history; the local SharedPreferences cache exists only for offline access and gets replaced when sync succeeds.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Repository sync

- [x] **Task 1: Add `refreshFromServer(serial)` to `NfbCalibrationRepository`**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  Add `Future<void> refreshFromServer(String serial) async {...}` to the existing class. Implementation:
  - Call `await _api.list(serial)` — returns `List<NfbCalibrationData>` already mapped from proto records (see `NfbCalibrationGrpcApi.list` at `lib/Bci/NfbCalibrationGrpcApi.dart:28`).
  - Trim the result to `_maxEntries` (20) if longer — `final trimmed = list.length > _maxEntries ? list.sublist(0, _maxEntries) : list;`. Preserve server-returned order (do not re-sort) — the server controls history ordering for this milestone.
  - Encode to JSON via `jsonEncode(trimmed.map((e) => e.toJson()).toList())` and write to `_prefs.setString(_keyFor(serial), encoded)` — same key/encoding as the existing `record()` method so subsequent `history(serial)` reads return the refreshed list.
  - Wrap the entire body in `try { ... } catch (Object e) { logPrint('NfbCalibrationRepository: refreshFromServer failed for $serial: $e'); }` — errors are logged, never rethrown (caller fires-and-forgets, but the repository must not crash an unawaited future with an unhandled exception).
  - Replace local cache unconditionally on success — server is authoritative. Do not merge with local entries.

### Phase 2: Trigger sync on scan

- [x] **Task 2: Fire-and-forget refresh in `BciDeviceManager.startScan()`** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  In `startScan()` (currently at lines 133–187), immediately after the existing `unawaited(_repository.fetchKnownSerials()...)` block (lines 143–146) and before `final cachedSerials = _repository.cachedSerials();` (line 148), insert a loop:
  - Iterate `_repository.cachedSerials()` — same source the existing auto-connect logic uses below. Reading once here is fine; the underlying cache is in-memory.
  - For each serial, call `unawaited(_nfbCalibrationRepository.refreshFromServer(serial).catchError((Object e) => logPrint('BciDeviceManager: refreshFromServer failed for $serial: $e')));`. The `catchError` is defensive — `refreshFromServer` already swallows errors internally, but matching the existing `fetchKnownSerials` pattern keeps unawaited-future safety consistent.
  - Empty cache → loop body runs zero times → no API calls, as required (first BCI screen open on a fresh install must not trigger a refresh).
  - Do not await the loop or block scanning on it. Behaviour after this task: any cached serial gets its history replaced with the server snapshot the next time the BCI screen opens; calibration auto-restore via `latestValid(serial)` in `connectDevice()` (line 199) then sees the fresh data.

<!-- orchestrator-sessions
planner: 79e4dae7-b78a-4219-9ce7-44c1edfebeba
elapsed: 311
implementer: c57ef78f-9292-4028-9365-c1235db27381
-->
