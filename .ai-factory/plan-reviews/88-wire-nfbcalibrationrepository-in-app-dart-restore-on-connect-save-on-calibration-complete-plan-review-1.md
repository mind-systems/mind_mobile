# Plan Review: Wire NfbCalibrationRepository in App.dart + restore on connect + save on calibration complete

**Plan:** `.ai-factory/plans/88-wire-nfbcalibrationrepository-in-app-dart-restore-on-connect-save-on-calibration-complete.md`
**Risk Level:** 🟡 Medium

### Context Gates

- **RULES.md** — `WARN`. Rule 2 says "App.dart is infrastructure only (DB, HTTP, notifiers, sync). Module concerns belong in the module's Service or coordinator." Wiring `NfbCalibrationRepository` into `App.dart` is consistent with how other BCI infrastructure (`bciProvider`, `bciRepository`, `bciDeviceManager`, `bciNotifier`) is currently wired there, so this is acceptable — but see Critical Issue #1 about over-exposing it as a public field.
- **ARCHITECTURE.md** — not re-read in this review, no obvious DI-graph conflict given the existing BCI wiring pattern in `App.dart`.
- **ROADMAP.md** — not re-read; plan 86 already shipped the repository and this is the wire-up follow-up.

### Critical Issues

#### 1. `importCalibration` is called BEFORE `_provider.connect(serial)` — likely wrong order
Task 3 inserts:
```dart
final cal = _nfbCalibrationRepository.latestValid(serial);
if (cal != null) await _provider.importCalibration(cal);
```
**before** `await _provider.connect(serial);` inside `connectDevice` (`lib/Bci/BciDeviceManager.dart:177-178`).

`NeiryBciProvider.importCalibration` (`lib/Bci/NeiryBciProvider.dart:393-409`) calls `neiry.NfbCalibrator.importCalibrationData(neiryData)`. The matching live path `neiry.NfbCalibrator.calibrateIndividual()` (line 360) is only reached via `startCalibration()`, which the manager only calls after a successful connect + impedance step. There is no evidence in this codebase that `NfbCalibrator.importCalibrationData` is safe to call before the SDK has a connected device — the plan assumes it but does not verify it.

Two failure modes are possible:
- The SDK silently ignores the import because no device is bound → restored calibration never takes effect and the whole feature is a no-op.
- The SDK throws → falls through into the existing `catch (e)` block on line 184 and the user can no longer connect at all (see Critical Issue #3).

**Fix:** Move the restore call to **after** a successful `_provider.connect(serial)` (e.g. immediately after `_connectedSerial = serial;`), or document/verify that the Neiry SDK explicitly supports pre-connect import.

#### 2. Restored calibration never reaches `ready` state — feature is functionally inert
After a successful restore + connect, the manager still transitions to `BciConnectionState.impedance` (line 180). The UI flow expects the user to then call `startCalibration()`, which would invoke `neiry.NfbCalibrator.calibrateIndividual()` and **overwrite** the just-restored calibration when `BciCalibrationCompleted` fires.

So as currently scoped, "restore on connect" has no observable effect: the user is still forced through calibration, and the restored data is replaced on the spot.

This is a fundamental design gap, not a code issue — the plan needs to decide one of:
- After a successful restore, skip impedance/calibrating and transition directly to `ready`.
- After a successful restore, transition to `impedance` but expose a flag/signal to the UI so it can offer the user a "skip calibration" path.
- Explicitly document that the restore is only used by a future code path (e.g. background session start without UI calibration) — in which case this plan is incomplete and should not ship without that consumer.

Without a decision here, Task 3 ships dead code.

#### 3. A broken cached calibration entry blocks all future connects
Plan text: "importCalibration failures here should propagate into the existing `catch (e)` block exactly like a failed `connect()`."

That means if the persisted JSON deserializes into an `NfbCalibrationData` that the Neiry SDK rejects (e.g. corrupted floats, future schema drift, an unknown `failReason` string — note `firstWhere` on line 396 throws `StateError` if the name doesn't match any enum value), the user will be unable to connect at all, with no automatic recovery. The error is logged as `"BciDeviceManager: connect failed: ..."` which is also misleading.

**Fix:** Wrap the restore in its own try/catch that logs and proceeds without throwing, so a corrupt cache degrades to "no restore, normal calibration flow" instead of "device cannot connect."

### Major Issues

#### 4. `nfbCalibrationRepository` should be a local variable, not an `App` public field
Task 1 adds a public `final NfbCalibrationRepository nfbCalibrationRepository;` on `class App` and threads it through `App._({...})`. But the analogous `BciDeviceRepository` is constructed as a local in `initialize()` (line 162) and **not** exposed on `App.shared`. A search confirms nothing reads `App.shared.bciRepository`, and nothing in the plan introduces a reader for `App.shared.nfbCalibrationRepository` either — its only consumer is `BciDeviceManager`, which receives it via constructor.

Exposing it on `App` adds surface area for no current benefit and diverges from the existing pattern. **Make it a local variable in `initialize()`** (constructed right after `final prefs = await SharedPreferences.getInstance();`) and just pass it into `BciDeviceManager(...)`. Drop the field and the `App._` constructor parameter entirely.

#### 5. Persisting invalid calibrations crowds out valid ones (Task 4)
`NfbCalibrationRepository` keeps a FIFO of 20 entries and `latestValid` walks newest→oldest looking for `isValid == true`. Task 4 persists **every** `BciCalibrationCompleted`, including events where `data.isValid == false` (the mapping at `NeiryBciProvider.dart:367-380` populates `isValid` from the SDK and emits the event regardless). A run of 20 failed calibrations would evict the last valid one and leave `latestValid` returning `null` forever — effectively defeating the restore.

**Fix:** Gate persistence on `data.isValid` (`if (data.isValid && _connectedSerial != null) unawaited(...)`), so failed attempts neither pollute the history nor displace good entries. If invalid entries must be retained for diagnostics, store them in a separate bucket or bump the cap.

### Minor Issues

#### 6. Confirm switch arm syntax change is exhaustiveness-safe
Task 4 rewrites `case BciCalibrationCompleted(data: final _):` to `case BciCalibrationCompleted(data: final data):`. This is valid Dart pattern syntax and preserves exhaustiveness over the sealed `BciCalibrationEvent`. ✓

#### 7. `unawaited` import claim — verified
Plan claims `dart:async` is already imported via the top-of-file `import 'dart:async';`. Confirmed at `lib/Bci/BciDeviceManager.dart:1`. ✓

#### 8. `_connectedSerial!` dereference inside listener — safe under current threading
Plan uses `_connectedSerial!` after a null check inside a synchronous listener block. Dart is single-threaded; nothing between the `if` and the `record(...)` call yields. Safe. ✓

### Positive Notes

- Good separation of concerns: Task 2 keeps `BciDeviceManager`'s public surface unchanged and only adds the repository as a private field, in line with the project's constructor-injection rule (`RULES.md` #3).
- Plan correctly notes the App.dart single-line / no-trailing-comma style for `initialize()` and the multi-line trailing-comma style for the existing `BciDeviceManager(...)` invocation — these two coexist in the same file and are easy to mix up.
- Task 4 correctly avoids gating persistence on `_state == calibrating`, so a late-arriving event after a state transition still persists. Good defensive thinking.
- Plan correctly identifies Task 2 as a dependency of Tasks 3 & 4.

### Required Changes Before Implementation

1. **Resolve Critical #1** — verify import-before-connect or move import to after connect.
2. **Resolve Critical #2** — decide and document the post-restore state transition, or explicitly mark this plan as wiring-only with no behavioral effect yet.
3. **Resolve Critical #3** — wrap the restore in its own try/catch so a bad cache entry does not brick connect.
4. **Resolve Major #4** — drop the public `App` field; keep `nfbCalibrationRepository` local to `initialize()` to match the `BciDeviceRepository` pattern and `RULES.md` #2.
5. **Resolve Major #5** — gate persistence on `data.isValid` to protect the FIFO from invalid entries.
