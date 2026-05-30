## Code Review

**Plan:** `86-implement-nfbcalibrationrepository-local-cache-only.md`
**Files reviewed:**
- `lib/Bci/NfbCalibrationRepository.dart` (new, 46 lines)

### Verification against plan

| Plan requirement | Status |
|---|---|
| Pure-Dart class in `lib/Bci/` | ✓ — no Flutter/Riverpod imports |
| Imports: `dart:convert`, `shared_preferences`, `NfbCalibrationData` | ✓ |
| Constructor `NfbCalibrationRepository({required SharedPreferences prefs})` | ✓ — mirrors `BciDeviceRepository` shape |
| Key `bci_nfb_cal_history_<serial>` | ✓ |
| Max 20 entries | ✓ |
| `record(serial, data)` async, prepend + truncate + await `setString` | ✓ |
| `latestValid(serial)` sync, first valid or null | ✓ |
| `history(serial)` sync, full cached list | ✓ |
| No gRPC API, no DI wiring this task | ✓ |

### Correctness analysis

1. **`history()` JSON shape handling — correct.** `jsonDecode` returns `Map<String, dynamic>` for JSON objects, so `whereType<Map<String, dynamic>>()` matches every well-formed entry. Non-map elements (a defensive case) are silently dropped, which is consistent with `BciDeviceRepository.cachedSerials`' "whereType<String>()" pattern.

2. **`history()` defensive parsing — covers all reasonable failures.** The `try/catch` spans `jsonDecode` *and* the `.map(NfbCalibrationData.fromJson)` pipeline. `fromJson` does unchecked casts (`as bool`, `as num`, `DateTime.parse`) which would throw on schema drift; the surrounding `try/catch (_)` swallows those and returns `const []`. Good — entire cache is dropped if any entry is malformed, but for a 20-entry cache that's acceptable and matches the "drop the cache on any decode failure" intent of `BciDeviceRepository`.

3. **`record()` truncation — correct.** `[data, ...existing]` produces a mutable `List<NfbCalibrationData>`, prepended newest-first. `sublist(0, _maxEntries)` keeps the first 20 (the newest). Even if `existing` is the `const []` sentinel, the spread copies into a new mutable list, so no "modify-unmodifiable" error.

4. **`record()` await — correct.** `setString` is awaited, consistent with `BciDeviceRepository._writeCache`.

5. **`latestValid()` — correct.** Simple `for` loop returning the first `isValid == true`. Returns `null` when no valid entry exists. No issue with the empty-history case.

6. **Newest-first ordering invariant — preserved.** `record()` prepends; `history()` returns the decoded list in storage order; `latestValid()` walks forward and stops at the first valid hit — i.e. the most recent valid calibration, as intended.

### Runtime concerns

- **Concurrent `record()` calls race.** Read-modify-write on `SharedPreferences` with no lock — two near-simultaneous `record(serial, ...)` calls for the same serial can interleave and lose one entry. The plan's "Notes" section did not flag this, but the plan-review did. For the intended single-calibration-flow caller this is unlikely to trigger in practice and is documented as deferred-API scope, so non-blocking.
- **No `pubspec.yaml` change needed.** `shared_preferences` is already a dependency (used by `BciDeviceRepository`, `App.dart`, `SharedPreferencesStorage`); the new file does not pull anything new.
- **Package import path correct.** `package:mind/...` matches `pubspec.yaml` name `mind`.
- **Key namespace safe.** Prefix `bci_nfb_cal_history_` does not collide with existing keys (`bci_known_serials` is the only other `bci_` key).
- **No `dispose()` / no stream state.** Repository is stateless; nothing to leak.

### Style / minor notes

- `var newList = ...` could be `final` since it is rebound via assignment — actually it is reassigned in the `if` branch, so `var` is correct as written. No change.
- The `whereType<Map<String, dynamic>>()` could in theory miss a `Map<dynamic, dynamic>` if produced by a future codec, but `dart:convert`'s `jsonDecode` always returns `Map<String, dynamic>` for objects, so the filter is sound today. Non-blocking.

### No critical or correctness issues found.

REVIEW_PASS
