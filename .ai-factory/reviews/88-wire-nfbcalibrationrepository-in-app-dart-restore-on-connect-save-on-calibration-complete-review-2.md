# Code Review 2: Wire NfbCalibrationRepository in App.dart + restore on connect + save on calibration complete

**Plan:** `.ai-factory/plans/88-wire-nfbcalibrationrepository-in-app-dart-restore-on-connect-save-on-calibration-complete.md`
**Changed files:**
- `lib/Core/App.dart`
- `lib/Bci/BciDeviceManager.dart`

This review verifies that the actionable findings from review-1 were correctly resolved and re-checks the resulting code for fresh issues.

---

## Verification of Prior Findings

### ✅ Finding #1 (race widened by `importCalibration` await) — RESOLVED
`lib/Bci/BciDeviceManager.dart:213-215` now guards the terminal `_setState` with `if (_state == BciConnectionState.connecting)`. A `disconnect()` racing with `await _provider.importCalibration(cal)` will move `_state → disconnected`, and the resumed continuation correctly skips the override. The inline comment at lines 210-212 documents the intent clearly. This is a minimal, correct fix that also closes the equivalent pre-existing race around `await _provider.connect(serial)`.

### ✅ Finding #4 (serial-mismatch on late calibration events) — DOCUMENTED
`lib/Bci/BciDeviceManager.dart:79-83` carries an inline comment acknowledging the edge case (disconnect → reconnect-to-different-device delivering a late `BciCalibrationCompleted` event that would record under the new serial). Given that calibration events fire immediately during `calibrateIndividual()` per the Neiry SDK, accepting this as a thin race is reasonable. The acknowledgement is the right move at this scope.

### ✅ Finding #5 (silent write errors on `record()`) — RESOLVED
`lib/Bci/BciDeviceManager.dart:85-87` now wraps the unawaited `record()` in `.catchError((Object e) => logPrint('BciDeviceManager: nfbCalibration record failed: $e'))`, matching the pattern used by `registerDevice` (lines 194-196). Persistence failures are now visible in logs.

### ⏭ Findings #2, #3 — Deferred (product/UX decisions)
These were flagged as scope decisions in review-1 (bypassing impedance contact-quality check; `BciPairingState.calibration` staying null after restore). Not addressed in this diff, which is correct — they require product input and likely a follow-up plan. They are not regressions caused by this PR's diff in isolation.

### ⏭ Finding #6 (import ordering) — Cosmetic
Implementer placed `NfbCalibrationRepository.dart` between `BciDeviceRepository.dart` and `IBciDeviceProvider.dart` (matching my prior suggestion to group repository imports). Strict alphabetical ordering (B, I, N) would have been slightly cleaner, but this is cosmetic and `dart format` does not normalize import order. Non-issue.

---

## Fresh Re-check of Changed Code

`connectDevice` (lines 189-220):
- Outer `try` still catches `_provider.connect(serial)` failures → `_setState(disconnected)`. ✓
- Inner `try` around `_provider.importCalibration(cal)` correctly absorbs SDK rejection (corrupt cache, schema drift, `firstWhere` StateError on unknown `failReason`). `restored` stays `false`, normal calibration flow proceeds. ✓
- `_connectedSerial = serial` is set **before** the import. If `disconnect()` runs between connect and the guard, it nulls `_connectedSerial` and sets `_state → disconnected`; the guard then skips the terminal `_setState`. The `_connectedSerial` write is harmless in that window because `disconnect()` overwrites it back to null. ✓
- `registerDevice` is unawaited above the restore; survives a thrown `importCalibration`. ✓

`_subscribeProviderStreams` calibration listener (lines 74-94):
- Pattern match `BciCalibrationCompleted(data: final data)` preserves exhaustiveness over the sealed `BciCalibrationEvent`. ✓
- `data.isValid && _connectedSerial != null` gate protects the 20-entry FIFO from invalid-entry eviction and from null-serial writes. ✓
- `_connectedSerial!` dereference is safe under Dart's single-threaded listener semantics (no awaits between check and use). ✓
- `unawaited(...catchError(log))` matches the file's idiom. ✓

`App.dart` (lines 159-172):
- Local construction with single-line style. No `App.shared` field added, matching `BciDeviceRepository` precedent. ✓
- Single named argument added to the existing multi-line `BciDeviceManager(...)` call, preserving trailing-comma style. ✓
- No unused imports; no dead code. ✓

---

## Pre-existing Concerns Worth Noting (Not Findings)

For posterity — these are not introduced by this PR but the new `await _provider.importCalibration` widens the window for two of them:

1. The unexpected-disconnect listener (`lib/Bci/BciDeviceManager.dart:61-73`) intentionally ignores `BciConnectionState.disconnected` from the provider when `_state == connecting`. If the SDK reports a real BLE drop during the import await, that signal is now swallowed for the duration of the import, and a healthy-looking `ready`/`impedance` may follow until the next event triggers re-evaluation. This is pre-existing and the guard added in finding #1 does not address the inverse direction. Out of scope here; worth a future task.
2. `NfbCalibrationRepository.record` (`lib/Bci/NfbCalibrationRepository.dart:37-45`) performs read-then-write on `SharedPreferences` non-atomically. Two concurrent unawaited `record()` calls could each read the same state and one write would lose the other. Calibration events arrive serially in practice, so this is theoretical only.

Neither is blocking for this PR.

---

REVIEW_PASS
