# Code Review: Implement `NeiryBciProvider` (33)

**Plan:** `.ai-factory/plans/33-implement-neirybciprovider.md`
**Files reviewed:** 1 (`lib/Bci/NeiryBciProvider.dart`)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture** — no `.ai-factory/ARCHITECTURE.md` present; no boundary breach observed. The adapter is the only file importing `package:neiry_kit/neiry_kit.dart` and no public member, parameter, or stream payload exposes a plugin type. ✅ pass.
- **Rules** — no `.ai-factory/RULES.md` present. ✅ pass.
- **Roadmap** — milestone 33 corresponds to "Implement NeiryBciProvider"; the code matches that scope. ✅ pass.

## Cross-checks against the interface and the SDK

- `IBciDeviceProvider` defines `void dispose()` (synchronous return). The implementation honors that signature and detaches the async teardown behind `unawaited(_doDispose())`.
- All five `@override` members on `IBciDeviceProvider` are implemented (`scan`, `connect`, `disconnect`, `startCalibration`, `dispose` plus the four stream getters).
- `Device.connectionStateStream`, `resistanceStream`, `batteryStream` are broadcast streams (built via `receiveBroadcastStream`), so the provider listening alongside the SDK's internal `_startStateTracking()` listener is supported.
- `Device.dispose()` is idempotent and `Device.disconnect()` issues the native disconnect; back-to-back `disconnect()` + `dispose()` calls in `NeiryBciProvider.disconnect()` and `_doDispose()` are safe per the SDK contract.
- `CalibrationEvent` is sealed with exactly two subtypes, so the `switch` in `startCalibration` is exhaustive; `CalibrationCompleted.data` is correctly dropped per the plan.
- `CalibrationStage.stage1..stage4` map to `index` 0..3, so `stage.index + 1` produces the required 1..4 domain values.
- `NeiryConnectionState` enum has exactly `disconnected`, `connected`, `unsupportedConnection`; the `_onNeiryConnectionState` switch is exhaustive.

## Findings

### Issues (non-blocking)

1. **`disconnect()` is not exception-safe.** Unlike `_doDispose()`, `disconnect()` does not wrap `_device?.disconnect()` / `_device?.dispose()` in `try`. If the native call throws (e.g. a transient `MethodChannel` failure or the device having gone into an invalid native state), the exception propagates, leaving:
   - `_device` still non-null (leaks the `Device` handle),
   - `_connectionStateController` never emitting the final `BciConnectionState.disconnected`,
   - subscriptions already cancelled — so any subsequent state recovery from the native side is silently lost.

   Recommendation: mirror `_doDispose()` — wrap the two awaits in a try/catch that `logPrint`s and proceeds to null `_device` and emit `disconnected`. The interface contract says `disconnect()` returns `Future<void>` with no documented exceptions, so callers won't be prepared to handle a throw.

   File: `lib/Bci/NeiryBciProvider.dart:170-176`.

2. **`connect()` has no guard against being called twice.** If `connect(serial)` is invoked while `_device` is already non-null:
   - the previous `Device` handle is lost (leaks the native handle + its state-tracking subs the SDK started internally),
   - `_connectionSub`, `_resistanceSub`, `_batterySub` are overwritten in `_subscribeDeviceStreams()` without being cancelled, leaking the prior subscriptions.

   The interface implicitly requires `disconnect()` first, but a defensive guard would harden the provider. Either:
   - assert/throw if `_device != null`, or
   - call `_cancelDeviceSubscriptions()` and `_device?.dispose()` at the top of `connect()` before creating a new device.

   The plan flagged this as optional; flagging again because the leak is silent.

   File: `lib/Bci/NeiryBciProvider.dart:62-67`.

3. **Connect-time partial-failure cleanup is missing.** Sequence `await _locator.createDevice(serial)` → `await _device!.connect()` → `await _device!.start()` — if `start()` throws (e.g. native rejects because the BLE link hasn't actually completed; `Device.connect()` is documented as non-blocking), the provider keeps a partially-initialized `_device` with no subscriptions. Caller's natural reaction is to retry `connect()`, which compounds finding #2.

   Recommendation: wrap connect/start in `try { ... } catch (e) { await _device?.disconnect(); await _device?.dispose(); _device = null; rethrow; }`.

   File: `lib/Bci/NeiryBciProvider.dart:62-67`.

4. **`dispose()` fire-and-forget is undocumented in the implementation.** The interface contract permits `void dispose()` and the plan justifies the `unawaited(_doDispose())` choice, but the implementation has no comment explaining that the native teardown continues in the background. A reader is liable to "simplify" this by making `_doDispose` synchronous, removing the awaits, and breaking the teardown sequence.

   Recommendation: add a single-line comment above `unawaited(_doDispose())` clarifying intent ("Interface returns `void`; defer native teardown to a microtask").

   File: `lib/Bci/NeiryBciProvider.dart:181-183`.

5. **No comment on the deliberate `disconnected` emission at the end of `disconnect()`.** The flow cancels `_connectionSub` and then explicitly adds `BciConnectionState.disconnected` to `_connectionStateController`. This is correct (the native event would otherwise be missed because the sub is gone), but a future maintainer may see the redundant emission and try to remove it.

   File: `lib/Bci/NeiryBciProvider.dart:175`.

6. **`_signalQualityController` is not drained on `disconnect()`.** The provider does not emit a final empty/cleared `List<BciChannelQuality>` after disconnect. Listeners that cache the last value (e.g., a Riverpod selector keyed off this stream) will keep showing stale impedance bars until the controller is closed in `dispose()`. Not a bug per the interface — but worth flagging because the manager (`BciDeviceManager`, milestone 3+) will need to clear quality UI itself.

   File: `lib/Bci/NeiryBciProvider.dart:170-176`.

### Nits

- The mixed import order (`'IBciDeviceProvider.dart'` and `'Models/...'` before `'../Logger.dart'`) violates the typical lint `directives_ordering`, which orders relative imports alphabetically. If `flutter analyze` ran clean (Task 9), the project doesn't enforce that rule — fine.
- `BciCalibrationCompleted` is constructed as `const BciCalibrationCompleted()` (correct, the type has a const constructor). The other two events are not const-constructed because they carry runtime fields. Consistent.
- The non-finite-before-thresholds order in `_onResistance` (line 119) is correct and explicit, addressing the NaN concern raised in the plan review.

## Positive Notes

- Exhaustive switches on `NeiryConnectionState` and `CalibrationEvent` will surface upstream SDK additions as compile errors. Good defensive use of sealed/enum patterns.
- The channel-count mismatch is logged AND mitigated by clamping with `min(min(...), ...)` — both belt and suspenders.
- `NaN`/non-finite impedance is checked before threshold comparisons, eliminating the ambiguity around `NaN > 200`.
- `_doDispose` cleanly separates `disconnect()`'s contract (just disconnect) from `dispose()`'s contract (full teardown), and `disconnect()` correctly leaves `_calibrationSub` alone (only `dispose()` cancels it).
- Private subscription field types preserve `neiry_kit` types (correct — they are private and let the analyzer catch type drift) while no public member leaks them.
- `_locator` is intentionally NOT disposed — correct, since `DeviceLocator` is a process-wide singleton in the SDK.
- The `logPrint` substitution for the spec's `Logger.error` matches the project's actual logging utility.
