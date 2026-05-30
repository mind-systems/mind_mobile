## Plan Review

**Plan:** `86-implement-nfbcalibrationrepository-local-cache-only.md`
**Risk Level:** 🟢 Low

### Context Gates
- **ARCHITECTURE.md** — PASS. The plan explicitly preserves the "Domain is pure Dart — no Flutter or Riverpod imports" rule (line 225 of ARCHITECTURE.md). `lib/Bci/` is the correct location per the domain layer convention; `BciDeviceRepository.dart` lives there with the same `(api, prefs)` constructor pattern the new class mirrors.
- **RULES.md** — PASS. No service interface, no module wiring, no App.dart edits — fully avoids the "do not add module-specific state to App.dart" rule. Repository takes its `SharedPreferences` via constructor (DI rule).
- **ROADMAP.md** — Not blocking. Plan declares this is the local-cache slice of a larger BCI/NFB calibration milestone; the follow-up (gRPC API + DI wiring into `App.shared`) is explicitly deferred and labelled.

### Codebase verification
- `lib/Bci/Models/NfbCalibrationData.dart` exists with `toJson()` / `fromJson(Map<String, dynamic>)` and the constructor shape the plan assumes. ✓
- `lib/Bci/BciDeviceRepository.dart` exists with the exact `final SharedPreferences _prefs;` + named-arg constructor pattern the plan mirrors. ✓
- `shared_preferences` is already a project dependency (used in `App.dart`, `SharedPreferencesStorage.dart`, `BciDeviceRepository.dart`) — no `pubspec.yaml` change needed. ✓
- The chosen key prefix `bci_nfb_cal_history_` does not collide with existing keys (`bci_known_serials` is the only `bci_` key currently in use). ✓
- The path `lib/Bci/NfbCalibrationRepository.dart` is free (no existing file). ✓

### Critical Issues
None.

### Suggestions (Non-Blocking)

1. **Task 2: widen the `try/catch` to cover element mapping, not just `jsonDecode`.**
   The plan says "Wrap `jsonDecode` in `try/catch`" but `NfbCalibrationData.fromJson` performs unchecked casts (`json['isValid'] as bool`, `(json['individualFrequency'] as num)`, `DateTime.parse(json['calibratedAt'] as String)`) — any shape drift in an old persisted entry will throw a `TypeError` or `FormatException` *after* `jsonDecode` succeeds. To truly match `BciDeviceRepository.cachedSerials`' defensive intent ("return `const []` on any decode failure"), the `try/catch` should wrap the whole decode+map block, not just the `jsonDecode` call. Consider explicitly noting this in the task wording.

2. **Task 4: concurrent writers can lose entries.**
   `record()` does read-modify-write on `SharedPreferences` without a lock. Two concurrent `record(serial, ...)` calls for the same serial can interleave and drop one of the calibrations. For a single-device calibration screen this is unlikely in practice, but worth a one-line note in the plan acknowledging the assumption ("calibrations are recorded sequentially from a single calibration flow — no concurrency guard is needed for the local cache").

3. **Task 3: `firstWhere(..., orElse: () => null)` requires a typed list to allow `null`.**
   Minor implementation detail — `List<NfbCalibrationData>.firstWhere` returns non-nullable, so `orElse: () => null` won't type-check without `.cast<NfbCalibrationData?>()` or a manual `for` loop. The plan already lists the `for`-loop alternative, so this is just a flag for the implementer to pick the loop or rely on `.firstWhereOrNull` (from `collection`) — `collection` is already transitively available via Flutter; verify before assuming.

4. **No-test policy is acknowledged but lossy here.**
   The plan opts out of tests ("Testing: no"). The repository logic is pure, side-effect-free at the boundary, and trivially testable with `SharedPreferences.setMockInitialValues`. Given how cheap the test would be vs. the cost of silently broken history parsing, a single happy-path + truncation test would be high-value. Optional — not blocking.

### Positive Notes
- Scope is correctly minimal — no premature gRPC/DI/App.shared churn.
- Mirrors `BciDeviceRepository` field/constructor/defensive-decode patterns exactly, which keeps the BCI domain layer consistent.
- Key naming (`bci_nfb_cal_history_$serial`) is self-describing and namespace-safe.
- `_maxEntries = 20` cap is a sensible bounded-storage choice for a local cache.
- Newest-first ordering is consistent between `record` (prepend) and `history` (read), so `latestValid` doesn't need to sort.

PLAN_REVIEW_PASS
