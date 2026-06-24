# Plan: B2 · Characterization — full teardown chain (L1 + classifier-disposal ordering)

## Context
Add a characterization test suite that pins the **full** unexpected-drop teardown chain in `NeiryBciProvider` — proving a thrown `cancel()`/classifier `dispose()`/`device.disconnect()`/`device.dispose()` anywhere in the chain still reaches the locator recreate (L1), and that the canonical teardown unit (stopStream → cancel fan-in → dispose classifiers → device.disconnect → device.dispose → locator.dispose + recreate) never splits or reorders. This is the second half of the contract (with B1) that the C1 actor refactor must keep green unchanged.

## Settings
- Testing: yes (the milestone deliverable is a test suite)
- Logging: minimal
- Docs: no

## Spec line-number mapping (IMPORTANT — spec uses stale numbers)
The spec note `.ai-factory/notes/161-bci-characterization-full-teardown.md` and the milestone text reference pre-port line numbers. The A3 port refactor moved the chain. Map to the **current** `lib/Bci/NeiryBciProvider.dart`:

| Spec ref | Meaning | Current location |
|---|---|---|
| `:518` stopStream | stop SDK threads | `_teardownAfterUnexpectedDrop()` → `device?.stopStream()` `:409` |
| `:521-530` cancel ×10 | cancel fan-in subs | `:412-421` (10 `await sub?.cancel()`) |
| `:534-549` dispose ×4 classifiers | classifier teardown | `classifierSet?.dispose()` `:425` (now one `ClassifierSet.dispose()` port call; the four-classifier disposal lives inside the adapter) |
| `:556`/`:557` device disconnect/dispose | native release | `:432`/`:433` |
| `:561-562` try/finally | reach recreate | `:437-439` `finally { await _resetLocatorSession(); }` |
| `:468` recreate | new locator | `_resetLocatorSession()` → `_locator = _locatorFactory();` `:365` |

All ports (A1 `LocatorPort`, A2 `DevicePort`, A3 `ClassifierFactory`/`ClassifierSet`) and the B1 harness already exist. The provider is injectable via `NeiryBciProvider({locatorFactory, classifierFactory})`.

## Harness reuse decision
Per the spec ("build on B1's harness — reuse, do not re-derive"), reuse the **B1 harness design**. The existing codebase keeps fakes per-file (A3 and B1 each define their own `FakeClassifierSet`), so this suite is **self-contained**: it defines its own copies of the B1 harness fakes (adapted) plus the new throw-on-cancel / ordering instrumentation. **Do not edit the committed B1 file** (`test/Bci/neiry_bci_provider_locator_device_races_test.dart`) — it is the already-green contract and must stay untouched.

New test file: `test/Bci/neiry_bci_provider_full_teardown_test.dart`

## Tasks

### Phase 1: Harness

- [x] **Task 1: Create the suite skeleton + adapted B1 harness fakes**
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  Create the new test file with the same imports as the B1 file (`dart:async`, `flutter_test`, the port interfaces, `BciLinkStatus`, `BciNfbData`, `CardioData`, `RrInterval`, `MotionData`, `BciChannelQuality`, `BciEmotionsData`, `BciDeviceInfo`, `NeiryBciProvider`). Copy and adapt from B1 (`test/Bci/neiry_bci_provider_locator_device_races_test.dart`):
  - `GatedFakeDevicePort` (with `throwOnDisconnect`/`throwOnDispose`, the three gating `Completer`s, `emitConnection`, `closeControllers`).
  - `RecordingLocatorPort` (vends a **fresh** `GatedFakeDevicePort` per `createDevice`; double-dispose throws `StateError`).
  - `RecordingLocatorRegistry` (`locatorFactory`, `instances`, `liveCount`, `createdCount`, `assertNoOrphan`).
  - `FakeClassifierSet` — use the **A3 variant** that has `bool throwOnDispose` + `disposeCallCount` (see `test/Bci/neiry_bci_provider_classifier_port_test.dart:120-165`) and add a `closeControllers()` helper (so the test can close the seven broadcast controllers when `dispose()` threw before closing them).
  - `FakeClassifierFactory(FakeClassifierSet)`.
  Add the `main()` stub with empty groups for Phase 2/3/4 (filled by later tasks).

- [x] **Task 2: Add throw-on-cancel + cancel-recording stream wrappers** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  The fan-in `cancel()` chain (`:412-421`) operates on subscriptions to device/classifier streams; to inject a throwing `cancel()` and to record cancel ordering, the underlying stream must vend a controllable subscription. Add:
  - `ThrowOnCancelStream<T> extends Stream<T>` wrapping an inner broadcast stream; its `listen(...)` returns a `_ControllableCancelSubscription<T>` that **delegates the full `StreamSubscription` surface** to the inner subscription but overrides `cancel()` to: (1) optionally append a label to a shared order recorder (Task 3), then (2) `await` the inner cancel, then (3) throw `StateError` **after** cancelling if a `bool Function()` throw-predicate returns true. `isBroadcast` must delegate to the inner stream. Enumerate the full surface so the class is not abstract — the provider only calls `cancel()`, but `StreamSubscription<T>` also requires `onData`, `onError`, `onDone`, `pause`, `resume`, `isPaused`, and `asFuture<E>([E? futureValue])`; delegate each to the inner subscription.
  - Wire one device fan-in stream (the `connectionStateStream`) and one classifier stream (e.g. `nfbStateStream`) through this wrapper, each driven by a `bool throwOnCancel` flag on the owning fake (`GatedFakeDevicePort.throwOnConnectionCancel`, `FakeClassifierSet.throwOnNfbCancel`). Default flags false → behaves exactly like the plain broadcast stream (B1 parity preserved).
  Rationale for "throw after cancelling": mirrors the spec's "thrown anywhere in the cancel chain still recreates" without leaving the underlying controller un-cancelled in the fake.

- [x] **Task 3: Add teardown-order recorder + connect-then-drop helpers** (depends on Task 2)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  - Add a shared `TeardownOrder` recorder: a `final List<String> steps = []`. Construct it **first**, then thread it through constructors in wiring order **recorder → registry → locator → device** (it must exist before the provider is built, because the registry's `locatorFactory` vends L0 inside the `NeiryBciProvider` constructor; each `RecordingLocatorPort` hands the recorder to every `GatedFakeDevicePort` it vends via `createDevice`). Do **not** use a late global. Each fake appends its step label on the relevant call: device `stopStream()` → `'stopStream'`; the wrapped connection-sub `cancel()` → `'cancelFanIn'`; `FakeClassifierSet.dispose()` → `'classifierDispose'`; device `disconnect()` → `'deviceDisconnect'`; device `dispose()` → `'deviceDispose'`; `RecordingLocatorPort.dispose()` → `'locatorDispose'`; and the registry factory appends `'locatorCreate'` when it vends a **replacement** locator — cleanly implemented as `if (instances.isNotEmpty) order.steps.add('locatorCreate')`, since L0 is the only call made while `instances` is empty. Labels are behavioral observations only — **no coupling to `_teardownComplete` or other gate field names** (must survive its removal in C1).
  - Add `_connectThenDrop({...})` — same shape as B1's helper (build provider with recording registry + fake classifier factory, `await connect()`, grab `lastCreatedDevice`, **replace the device + L0 gating completers with fresh unsettled ones**, `emitConnection(down)`, `await Future<void>.delayed(Duration.zero)`), returning a `_DropSetup` bundle (provider, registry, l0, device, classifierSet, order). Used by Tasks 4 and 6. (Task 5 deliberately does **not** use it — see its zone-binding note.)
  - Add `_completeTeardown(_DropSetup)` — completes the gates in canonical order with a `Future<void>.delayed(Duration.zero)` pump between each (mirror B1 `:375-384`).
  - Add `_connectThenDropRunToCompletion({...})` — variant that leaves all gates **pre-completed** and pumps the event loop until the teardown microtask finishes (a few `await Future<void>.delayed(Duration.zero)`), so ordering probes can read `order.steps` without manual gating.

### Phase 2: L1 — thrown teardown still reaches recreate

- [x] **Task 4: L1 probes — throwing classifier dispose / device disconnect / device dispose** (depends on Task 3)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  Group `Phase 2 — L1 thrown teardown still recreates`. Three pure-drop tests (no concurrent `disconnect()`), each setting exactly one throw flag **before** completing teardown, then asserting the recreate was reached:
  - `classifierSet.throwOnDispose = true` (swallowed by gate `:424-428`).
  - `device.throwOnDisconnect = true` (swallowed by gate `:431-436`).
  - `device.throwOnDispose = true` (swallowed by gate `:431-436`).
  For each: after `_completeTeardown`, assert `registry.createdCount == 2` (L0 + exactly one replacement — pure-drop churn caveat: exactly one create), `l0.disposeCount == 1`, `registry.liveCount == 1`, `registry.assertNoOrphan()`. Because a throwing `dispose()` skips the fake's controller-close, close exactly the controllers left open per case (avoids a "stream was not closed" flake), then `provider.dispose()` + pump:
  - `classifierSet.throwOnDispose = true`: classifier `dispose()` (`:425`) throws and is swallowed; device disconnect/dispose still run → call `classifierSet.closeControllers()` **only**.
  - `device.throwOnDisconnect = true`: disconnect (`:432`) throws so device `dispose()` (`:433`) is **skipped** (same try-block) and the classifier set was disposed normally → call `device.closeControllers()` **only**.
  - `device.throwOnDispose = true`: disconnect succeeds, dispose throws after it → device controllers stay open → call `device.closeControllers()` **only**.
  Assertions are behavioral (create/dispose counts + no orphan), not gate-field-coupled.

- [x] **Task 5: L1 probe — throwing subscription cancel still reaches recreate** (depends on Task 4)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  In the same group, add a test that injects a **throwing `cancel()`** into the fan-in chain (set `device.throwOnConnectionCancel = true`, or alternatively `classifierSet.throwOnNfbCancel = true`) before completing teardown. Key gate detail: the cancels at `:412-421` are **not** individually wrapped in try/catch, so a throwing cancel short-circuits the remaining chain and propagates to the outer `finally` (`:437-439`) → `_resetLocatorSession()` still runs → recreate is reached, and the rejected teardown microtask surfaces as an uncaught async error (nobody awaits `_teardownComplete` in a pure drop). To keep the probe deterministic and **behavioral**:
  - **Zone binding — critical:** the rejected future is `Future.microtask(...)` scheduled inside `_teardownAfterUnexpectedDrop()`, which runs synchronously inside the `_onConnectionStatus` callback. Dart delivers stream events in the **listen-time zone** — i.e. the zone where `device.connectionStateStream.listen(...)` ran inside `connect()` (`:185`/`:189`), **not** the `emitConnection()`-time zone. Therefore `connect()` itself must execute inside the same `runZonedGuarded` body; if `connect()` runs in the outer test zone (as B1's `_connectThenDrop` does), the rejection surfaces in the outer zone, flutter_test fails the test, and the guarded error list stays empty. So **do not reuse the outer-zone `_connectThenDrop` here** — inline the whole flow (provider construction + `connect()` + drop + `_completeTeardown`) inside one `runZonedGuarded`, capturing async errors into a list. After completing teardown, pump a couple of extra `await Future<void>.delayed(Duration.zero)` so the unhandled-rejection report reaches the guarded handler before asserting.
  - Assert the recreate was reached: `registry.createdCount == 2`, `l0.disposeCount == 1`, `registry.liveCount == 1`, `registry.assertNoOrphan()` — this is the L1 invariant.
  - Assert the captured error list contains the injected `StateError` (documents the gate-version behavior that a throwing cancel leaks past the microtask, without coupling to internals).
  - **Cleanup:** the throwing-cancel case short-circuits **before** both classifier dispose and device dispose, so neither closes its controllers → call **both** `device.closeControllers()` and `classifierSet.closeControllers()` before `provider.dispose()` + pump.
  - **Decision rule (per spec):** if the recreate invariant itself comes back **red** (recreate not reached / orphan / double-dispose), that is a real gate-version bug — fix it minimally in `lib/Bci/NeiryBciProvider.dart` (e.g. wrap the cancel chain `:412-421` in a try/catch mirroring the existing classifier/device wraps so the chain completes and recreate is reached cleanly), then the probe must stay green. Do **not** weaken the invariant to make it pass; only the captured-async-error assertion may be adjusted to whatever the corrected behavior is.

### Phase 3: classifier-disposal ordering

- [x] **Task 6: Ordering probes — canonical teardown unit never splits/reorders** (depends on Task 5)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  Group `Phase 3 — classifier-disposal ordering`. Using `_connectThenDropRunToCompletion`, drive a clean pure drop (no throws) to completion and assert `order.steps` equals the canonical unit in order:
  `['stopStream', 'cancelFanIn', 'classifierDispose', 'deviceDisconnect', 'deviceDispose', 'locatorDispose', 'locatorCreate']`.
  Add a second test that interleaves a concurrent `disconnect()` (queued behind the in-flight teardown via the gate) and asserts the canonical sub-sequence for the **drop teardown** still appears as one contiguous, correctly-ordered unit (`stopStream` → `cancelFanIn` → `classifierDispose` → `deviceDisconnect` → `deviceDispose` → `locatorDispose` → `locatorCreate`) — i.e. the unit is never split or reordered by the interleaving. Under the disconnect race use the **churn caveat**: assert `registry.liveCount <= 1` at all points and `registry.assertNoOrphan()` rather than a tight create count. Behavioral ordering assertions only.

### Phase 4: green-up

- [x] **Task 7: Run the suite and converge to green** (depends on Task 6)
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart` (and `lib/Bci/NeiryBciProvider.dart` only if a red probe forces a gate fix per Task 5's decision rule)
  Run `/usr/local/bin/flutter test test/Bci/neiry_bci_provider_full_teardown_test.dart`. Also run the B1 file to confirm it is still green and untouched: `/usr/local/bin/flutter test test/Bci/neiry_bci_provider_locator_device_races_test.dart`. Fix any non-determinism (insufficient `Future<void>.delayed(Duration.zero)` pumps), un-closed controllers, or stream-wrapper delegation bugs. Apply the decision rule only if a probe is genuinely red on an invariant. Final state: both suites green, assertions behavioral.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add full-teardown characterization harness with throw-on-cancel and ordering instrumentation"
- **Commit 2** (after tasks 4-5): "Add L1 probes: thrown cancel/dispose still reaches locator recreate"
- **Commit 3** (after tasks 6-7): "Add classifier-disposal ordering probes and green up the full-teardown suite"
