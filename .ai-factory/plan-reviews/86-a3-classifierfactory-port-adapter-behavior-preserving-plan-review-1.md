# Plan Review: A3 · ClassifierFactory port + adapter (behavior-preserving)

**Plan:** `86-a3-classifierfactory-port-adapter-behavior-preserving.md`
**Reviewed against:** actual `lib/Bci/` codebase, `neiry_kit` source, existing A1/A2 ports + tests
**Risk Level:** 🟢 Low

## Verification Summary

Every structural claim in the plan was checked against the live codebase and found accurate:

- **Line numbers are correct.** Classifier fields `:51-54`, inline cast `:171`, classifier construction `:172-175`, `connect()` body, `_subscribeDeviceStreams()` `:205-258`, `_teardownAfterUnexpectedDrop()` `:455-542`, `_cancelDeviceSubscriptions()` `:544-590`, teardown dispose `:510-529`, cancel-path dispose `:567-589` — all match `NeiryBciProvider.dart`.
- **Pattern parity confirmed.** `DevicePort`/`NeiryDeviceAdapter` and `LocatorPort`/`NeiryLocatorAdapter` follow exactly the narrow-port + thin-adapter shape the plan proposes to mirror. Domain mapping already lives in `NeiryDeviceAdapter` (resistance/connection-state), so moving the classifier `_on*` mapping into `NeiryClassifierSet` is consistent.
- **Stream types match.** neiry classifier getters confirmed: `NfbClassifier.stateStream → NfbUserState`, `errorStream → String`, `CardioClassifier.stateStream → CardioData`/`rrStream → RRInterval`, `EmotionsClassifier.stateStream → EmotionsStates`/`errorStream → String`, `MEMSClassifier.memsStream → List<MemsSample>`. The seven-stream port surface is complete and correct.
- **Model fields match the mappings.** `BciNfbData`, `CardioData`, `RrInterval`, `MotionData`, `BciEmotionsData` field names align with the verbatim-copied `_on*` bodies. Import paths (`../Models/…`, `../../Biometrics/Models/…`) resolve correctly from `lib/Bci/Ports/`.
- **No external coupling to removed members.** Grep confirms `_nfbClassifier`/`_cardioClassifier`/`_emotionsClassifier`/`_memsClassifier` and all five `_on*` methods are referenced only inside `NeiryBciProvider.dart`. Removing them is safe.
- **Call site stays valid.** `App.dart:193 NeiryBciProvider()` works unchanged because `classifierFactory` is an optional named param with a default — same pattern as the existing `locatorFactory`.
- **A2 test stays green (correctly predicted).** After Task 5, the default `NeiryClassifierFactory.build()` casts the `FakeDevicePort` → `TypeError`, thrown after `connect()` is forwarded (count 1) and before `_classifierSet` is assigned. The catch block's `_classifierSet?.dispose()` is a no-op (null) and falls through to `device.disconnect()`/`dispose()` (count 1 each) — exactly what `neiry_bci_provider_device_port_test.dart` asserts. The plan's claim that this remains a passing `TypeError` test is verified.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** PASS. The documented boundary "only `NeiryBciProvider` + the port adapters import `neiry_kit`" is preserved — new neiry imports are confined to `NeiryClassifierSet`/`NeiryClassifierFactory`, and the provider keeps its neiry import only for the calibrator (explicitly out of scope).
- **Rules (`RULES.md`):** PASS. Rule 3 ("all dependencies injected via constructor") is honored — `ClassifierFactory` is constructor-injected with a default. No App.dart state added (Rule 2). The stateless-Service rule (Rule 1) is N/A here.
- **Roadmap (`ROADMAP.md`):** PASS. A3 is an explicit milestone (`:294`); B2 (`:296`) depends on the classifier-disposal ordering this plan preserves. Linkage is present. (This is a behavior-preserving refactor, not feat/fix/perf, so roadmap traceability is informational.)

## Behavior-Preservation Analysis

I specifically stress-tested the "byte-identical production behavior" claim against the `connect()` error path, since that's where a port refactor most easily diverges:

- **Classifier construction is atomic.** All four neiry classifier factory constructors throw `StateError` on the *same* `device.isConnected` guard, with **no `await` between constructions**. So in the original, either all four are constructed or the first (`NfbClassifier`) throws and none are — there is no partial-construction state. The `NeiryClassifierSet` constructor reproduces this exactly: it builds all four synchronously, so a throw leaves `_classifierSet` unassigned (null) and the catch block disposes nothing — identical to the original disposing four null fields. **No leak regression.** ✅

## Findings (all non-blocking)

### 1. Task 3 omits the domain-model import list for `NeiryClassifierSet` (minor completeness)
The plan spells out imports for the `ClassifierSet` *port* (Task 1) but for the *adapter* (Task 3) only states the `neiry` import rule. The adapter will also need:
`SensorSource.dart` (for `SensorSource.neiry`), `CardioData.dart`, `RrInterval.dart`, `MotionData.dart`, `BciNfbData.dart`, `BciEmotionsData.dart`, plus `ClassifierSet.dart` and the `neiry` import.
An implementer can infer these from the copied mapping bodies, but listing them would match the precision of Task 1. Recommend adding `import '../../Biometrics/Models/SensorSource.dart';` explicitly to the task.

### 2. Recommend `late final` stream getters in `NeiryClassifierSet` (consistency / safety)
`NeiryDeviceAdapter` exposes its mapped streams as `late final Stream<…> x = _device.y.map(...)` rather than plain getters, so the mapped stream is created once. The plan describes the adapter getters as `_nfb.stateStream.map(...)` without specifying form. The provider subscribes to each exactly once, so a plain getter is functionally correct — but `late final` matches the sibling adapter and avoids constructing a fresh mapped stream per access. Recommend `late final` for parity.

### 3. Mapping-exception routing shifts from zone-error to subscription `onError` (trivial, worth acknowledging)
Today the `_on*` mapping runs inside the `listen()` data callback; a throw there would surface as an uncaught async (zone) error. After the move, mapping runs in the adapter's `.map()`, so a throw routes to the provider's subscription `onError:` (which logs). The mappings are pure field copies that cannot realistically throw, so this is effectively a no-op — but it is technically a behavioral shift in the error path, not strictly byte-identical. Acceptable and arguably an improvement; no action required beyond awareness.

## Positive Notes

- The plan correctly identifies that the factory is **stateless** (a plain instance, not a `Function()` like the locator) — the locator is recreated per connect because the SDK caches `clCDevice` per serial; the classifier factory has no such session state. Good distinction.
- The `motionStream = _mems.memsStream.expand((batch) => batch.map(...))` choice exactly reproduces the `_onMemsBatch` per-sample fan-out — `expand` is the right operator.
- Per-classifier `try/catch` with isolation in `dispose()` preserves the existing "one failure doesn't skip the rest" semantics, and the plan explicitly flags the build/dispose ordering (`nfb → cardio → emotions → mems`) that B2 will assert.
- The single-coherent-edit instruction for Task 5 (constructor + fields + sub types + `connect()` + subscriptions + all three teardown paths in one pass) correctly avoids leaving the file in a non-compiling intermediate state.
- Test plan is well-scoped: the `FakeClassifierFactory` unblocks the full happy-path `connect()` that A2 had to skip, and the `throwOnDispose` hook directly sets up B2's teardown-chain coverage.

## Conclusion

The plan rests on an accurate reading of the codebase, faithfully extends the established A1/A2 port pattern, and its behavior-preservation claims hold up under error-path analysis. The three findings are minor completeness/consistency notes, none blocking. Safe to implement.

PLAN_REVIEW_PASS
