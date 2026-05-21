# Plan Review: Implement `NeiryBciProvider` (33)

**Plan:** `.ai-factory/plans/33-implement-neirybciprovider.md`
**Spec:** `.ai-factory/notes/15-neiry-bci-provider.md`
**Risk Level:** 🟢 Low

## Verification summary

I cross-checked every claim the plan makes about the target codebase against the
actual files:

- `lib/Bci/IBciDeviceProvider.dart` — matches plan: `scan()`, `connect`, `disconnect`,
  `connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`,
  `startCalibration()`, **`void dispose()`** (NOT `Future<void>`). Plan's note in Task 8
  about verifying the signature is correct, and the chosen `void dispose()` signature
  matches.
- `lib/Bci/Models/BciCalibrationEvent.dart` — sealed class with three subtypes
  (`BciCalibrationStageFinished(int stage)`, `const BciCalibrationCompleted()`,
  `BciCalibrationFailed(String reason)`). Positional, not named. The plan uses
  the right positional form (`BciCalibrationStageFinished(stage.index + 1)`,
  `BciCalibrationFailed(e.toString())`).
- `lib/Bci/Models/BciChannelQuality.dart` — named-parameter constructor with
  `channelName`, `impedanceOhm`, `level`; `BciSignalLevel { green, yellow, red }`.
  Plan matches.
- `lib/Bci/Models/BciDeviceInfo.dart` — `serial` + `name` only, both named. Matches.
- `lib/Bci/Models/BciConnectionState.dart` — `disconnected, scanning, connecting,
  impedance, calibrating, ready`. Matches.
- `lib/Logger.dart` — top-level `logPrint(Object?)`; no `Logger` class. Plan
  correctly redirects every `Logger.error` from the spec to `logPrint`.
- `neiry_kit/lib/src/api/device_locator.dart` — `requestDevices` returns
  `Stream<List<DeviceInfo>>`, emits once and closes, cancels in-flight scan on
  re-subscribe. `createDevice(String serial)` returns `Future<Device>`.
- `neiry_kit/lib/src/api/device.dart` — `Device.connect()` (with optional
  `bipolarChannels`), `start()`, `disconnect()`, `dispose()` all present.
  `connectionStateStream`, `resistanceStream`, `batteryStream` (typed
  `Stream<int>`) all present and check `_disposed` on read.
- `neiry_kit/lib/src/api/nfb_calibrator.dart` — `NfbCalibrator.calibrateIndividual()`
  is a static `Stream<CalibrationEvent>` factory. Events:
  `CalibrationStageFinished(stage: CalibrationStage)` and
  `CalibrationCompleted(data: IndividualNfbData)`. Plan correctly extracts
  `stage` and drops `data`.
- `neiry_kit/lib/src/models/calibration_stage.dart` — `CalibrationStage.stage1..stage4`
  with `code` 0..3. `stage.index + 1` and `stage.code + 1` both produce 1..4. Matches.
- `neiry_kit/lib/src/channel/enums.dart` — `NeiryConnectionState { disconnected(0),
  connected(1), unsupportedConnection(2) }`. Exactly three values; plan's exhaustive
  switch is correct.
- `neiry_kit/lib/src/models/resistance_data.dart` — `fromMap` divides raw values
  by 1000 (`(v as num).toDouble() / 1000.0`), so `values` is in **kΩ**, matching
  the spec's thresholds (50 / 200). Plan is correct.
- `pubspec.yaml` — `neiry_kit: path: ../neiry_kit` confirmed.

No factual errors about the codebase or the SDK API.

## Issues

### Minor — clarify, but not blocking

1. **`dart:math` import is missing from Task 1's import list.** Task 5 says
   "iterate up to `min(channelNames.length, values.length, channelCount)`",
   but `dart:math`'s `min` takes only two arguments. The implementer will
   either need to nest two `min` calls or compute it inline — either way,
   add `import 'dart:math' show min;` to Task 1, or replace the wording with
   an inline `length` reduction so no import is needed.

2. **Bucketing order for non-finite values (Task 5).** The plan says
   `value > 200 or NaN/non-finite → red`. In Dart, `NaN > 200` evaluates to
   `false`, so a naïve `if (value <= 50) green else if (value <= 200) yellow
   else red` chain happens to land NaN on `red` — but that's accidental.
   Recommend tightening the wording to: "If `!value.isFinite`, classify as
   `red` before any threshold comparison." Otherwise the implementer might
   reorder the branches and silently mis-classify NaN as green
   (`NaN <= 50` is also `false`, so this is technically safe, but explicit
   intent is better).

3. **Task 5's "once if they disagree" log is ambiguous.** The plan says
   "`logPrint(...)` once if they disagree". This reads as "once per
   emission" rather than "once across the provider's lifetime". Either
   interpretation is acceptable; please pick one. Once-per-emission needs no
   extra state; once-per-provider needs a `bool _loggedChannelMismatch`. I'd
   recommend once-per-emission for simplicity and to keep the class
   stateless on this dimension.

4. **Connect-failure cleanup (Task 3).** If `_device!.start()` throws after
   `_device!.connect()` succeeded, the provider is left with a connected
   device and no subscriptions wired. Callers can recover by calling
   `disconnect()`, but it's not stated. Optional improvement: wrap
   `connect`+`start` in a try/catch that calls `_device?.disconnect()` and
   nulls `_device` on failure before rethrowing. Not required for milestone
   2, but worth a sentence in Task 3.

5. **Idempotent `_subscribeDeviceStreams()` (Task 3).** The plan does not
   guard against a second `connect()` call while subscriptions are already
   live. If a caller mis-uses the provider, `_connectionSub` is overwritten
   and the old subscription leaks. The interface implicitly forbids
   re-connect without disconnect, but a one-line defensive
   `_cancelDeviceSubscriptions()` at the top of `_subscribeDeviceStreams()`
   would harden it. Optional.

6. **`dispose()` semantics with `void` return (Task 8).** The plan correctly
   keeps the signature `void dispose()` to match the interface. The
   suggested `unawaited(Future(() async { ... }))` pattern is acceptable but
   means callers cannot tell when the underlying device/controller teardown
   actually finishes — which is exactly what the interface doc already
   warns about ("any subsequent call on this instance is undefined").
   Please confirm in the code comment that this is deliberate; otherwise a
   reader will be tempted to "fix" it.

7. **`disconnect()` adds to `_connectionStateController` after canceling its
   own subscription (Task 7).** This is intentional — the provider needs to
   emit `disconnected` even when the native side did not — but it would be
   worth a one-line comment in the code so it isn't later "simplified" away.

8. **Private subscription field types leak `neiry_kit` types into private
   surface (Task 1).** The plan declares
   `StreamSubscription<NeiryConnectionState>?`,
   `StreamSubscription<ResistanceData>?`, and
   `StreamSubscription<CalibrationEvent>?`. These are *private* fields, so
   they do not violate the "neiry_kit type must not appear in any public
   member, method signature, or stream payload" rule from the plan's
   trailing notes. No action needed — flagging this so the implementer
   doesn't second-guess and erase the type information by switching to
   `StreamSubscription<dynamic>?`.

### Not an issue (sanity-checked)

- The `DeviceLocator` singleton lives across the entire app lifetime; the
  plan correctly does NOT call `_locator.dispose()` from
  `NeiryBciProvider.dispose()`.
- Re-calling `scan()` is safe — `DeviceLocator.requestDevices` cancels the
  prior scan subscription before starting a new one.
- The `connecting` emission on `NeiryConnectionState.connected` looks
  surprising but is intentional: `BciDeviceManager` owns the transition to
  `impedance`. The plan calls this out and the spec confirms it.
- The exhaustive switch on `NeiryConnectionState` (Task 4) and
  `CalibrationEvent` (Task 6) will produce compile errors if the upstream
  enum/sealed class gains a new variant. Correct.
- `_device?.disconnect()` followed by `_device?.dispose()` on a fresh
  `Device` is safe: `disconnect()` doesn't set `_disposed`, and `dispose()`
  is idempotent (early returns on `_disposed`). The double-call pattern in
  Tasks 7 and 8 is fine.

## Verdict

The plan is grounded in the actual codebase, the interface, and the SDK. All
type signatures, field names, and behaviours referenced in the plan match
what's on disk. The only concrete gap is the missing `dart:math` import for
`min`, and a couple of wording clarifications around NaN bucketing and the
"log once" semantics. None of these are blockers — they're worth tightening
but the implementer can proceed without them.

PLAN_REVIEW_PASS
