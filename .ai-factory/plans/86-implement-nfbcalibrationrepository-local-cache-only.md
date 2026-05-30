# Plan: Implement `NfbCalibrationRepository` (local cache only)

## Context
Introduce a pure-Dart repository that persists `NfbCalibrationData` per BCI device in `SharedPreferences`, exposing append / latest-valid / history reads. This is the local-cache-only first slice — no gRPC API wiring yet (added in a follow-up task).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Repository

- [x] **Task 1: Create `NfbCalibrationRepository` with constructor and key helpers**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  Create a new pure-Dart class `NfbCalibrationRepository` in `lib/Bci/`. Imports: `dart:convert`, `package:shared_preferences/shared_preferences.dart`, `package:mind/Bci/Models/NfbCalibrationData.dart`. Declare a private `final SharedPreferences _prefs;` field and the constructor `NfbCalibrationRepository({required SharedPreferences prefs}) : _prefs = prefs;` (mirrors the field+constructor pattern used in `lib/Bci/BciDeviceRepository.dart`). Add a private helper `String _keyFor(String serial) => 'bci_nfb_cal_history_$serial';` and a private `static const int _maxEntries = 20;`. Do NOT add a gRPC API dependency in this task.

- [x] **Task 2: Implement `history(serial)` synchronous read with JSON decoding**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  Add `List<NfbCalibrationData> history(String serial)` — reads the JSON array string at `_keyFor(serial)` from `_prefs.getString(...)`. If `null`, return `const <NfbCalibrationData>[]`. Wrap `jsonDecode` in `try/catch` (matching `BciDeviceRepository.cachedSerials` defensive parsing): if the decoded value is not a `List`, return `const <NfbCalibrationData>[]`; otherwise map each `Map<String, dynamic>` element through `NfbCalibrationData.fromJson` and return the resulting `List<NfbCalibrationData>`. The list is ordered newest-first (consistent with how `record` writes it). This is the in-memory cache read used by `latestValid` and external callers.

- [x] **Task 3: Implement `latestValid(serial)` synchronous read**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  Add `NfbCalibrationData? latestValid(String serial)` — calls `history(serial)` and returns the first entry whose `isValid == true`, or `null` if no such entry exists. Use `.firstWhere(..., orElse: () => ...)` with a sentinel-or-null pattern, or a simple `for` loop returning the first match — whichever stays clearest. No async, no I/O beyond what `history` does.

- [x] **Task 4: Implement `record(serial, data)` async write with prepend + truncate**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  Add `Future<void> record(String serial, NfbCalibrationData data) async`. Steps: (1) read existing list via `history(serial)`; (2) build a new list with `data` prepended at index 0, followed by the existing entries; (3) if `newList.length > _maxEntries`, take only the first `_maxEntries`; (4) JSON-encode the list by mapping `entry.toJson()` for each item and calling `jsonEncode(...)`; (5) `await _prefs.setString(_keyFor(serial), encoded);`. Always `await` the `setString` call — consistent with `BciDeviceRepository._writeCache` where every `SharedPreferences` write in the codebase is async/awaited. Do not catch errors here — let `SharedPreferences` failures propagate to the caller.

## Notes
- The repository is pure Dart — no Flutter or Riverpod imports, matching the domain-layer rule in `.ai-factory/ARCHITECTURE.md`.
- Wiring into `App.shared` and DI registration is intentionally NOT part of this milestone; that happens together with the gRPC API addition in a later roadmap task.
- Fewer than 5 tasks → single commit at the end, no commit plan.

<!-- orchestrator-sessions
planner: 4d01baf2-d8fa-40fd-a316-61851c67a9c6
elapsed: 336
implementer: d932a8ac-1aac-4448-89c4-e09ee66a11a0
-->
