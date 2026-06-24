# Plan Review: B1 · Characterization: locator/device races H1 + L2

**Plan:** `87-b1-characterization-locator-device-races-h1-l2-green-on-gate-version.md`
**Scope:** Test-only characterization suite (one new file) + conditional gate fixes in `NeiryBciProvider.dart`.
**Risk Level:** 🟢 Low — well-grounded, line-accurate, incorporates four prior plan-review notes.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md` present):** WARN-clean. The plan respects the port-seam boundary mandated by ROADMAP Phase 55 — fakes implement the narrow `LocatorPort`/`DevicePort`/`ClassifierFactory` interfaces (3–6 methods), never the vendor class. No boundary violations.
- **Rules (`.ai-factory/RULES.md` present):** Pass. The three project rules concern Module Services statelessness, App.dart purity, and constructor injection — none apply to a test suite. `NeiryBciProvider` already takes its ports via constructor injection, consistent with the DI rule.
- **Roadmap (`.ai-factory/ROADMAP.md` present):** Pass — strong linkage. The plan maps 1:1 onto the open milestone **Phase 55 / B1** (ROADMAP.md:295), including the same harness gotchas the roadmap calls out verbatim (concrete `BciDevicesGrpcApi` fake + mocked prefs; device fake with throw-injection + fresh-per-`createDevice`). Depends-on A1/A2/A3, all marked `[x]`. Spec note `156-bci-characterization-locator-device.md` referenced.

## Verification Performed

Every code reference in the plan was checked against the working tree:

| Plan claim | Verified |
|---|---|
| `_locatorFactory` ctor arg, mutable `_locator`, called once at `:54` | ✅ `NeiryBciProvider.dart:41–55` |
| `scan()` gates on `await _teardownComplete` `:118` then `yield* _locator.requestDevices` `:153` | ✅ |
| `connect()` gate `:160`, `createDevice` `:167`, failure cleanup `:172–184` (disconnect+dispose, **no** stopStream), `_resetLocatorSession` `:182` | ✅ |
| `_subscribeDeviceStreams()` runs only after success `:185`; failure path never subscribes | ✅ `:185`, `:188–193` |
| down handler idempotency guard `_device == null` `:257`; `_teardownAfterUnexpectedDrop` `:260/:375`; teardown microtask `:404`; `finally { _resetLocatorSession() }` `:438` | ✅ |
| `_resetLocatorSession` `:357`: `await _locator.dispose()` `:360` (try/catch double-dispose) then `_locator = _locatorFactory()` `:365`; no-op when `_disposed` | ✅ |
| `disconnect()` `:474` gates `:475`, unconditional `_resetLocatorSession()` `:502` | ✅ |
| `BciDeviceManager._attemptReconnect()` `:274` → `_provider.scan()` `:277`; listener `:68–74` fires only when `down && _state is BciActive` | ✅ `BciDeviceManager.dart` |
| `BciImpedance` is a `BciActive` subtype (precondition reachable via `connectDevice` success) | ✅ `BciConnectionState.dart:48` |
| `BciDeviceRepository` ctor takes **concrete** `BciDevicesGrpcApi` (not the interface) — public surface `listDevices`/`register`/`delete`, private `_client` | ✅ `BciDeviceRepository.dart:9–14`, `BciDevicesGrpcApi.dart:5–26` (plan-review #1 correct) |
| `NfbCalibrationRepository` ctor takes `NfbCalibrationGrpcApi`; existing `FakeNfbCalibrationGrpcApi implements NfbCalibrationGrpcApi` to mirror | ✅ `NfbCalibrationRepository.dart:16`, `nfb_calibration_repository_test.dart:14` |
| Default `NeiryClassifierFactory` cast throws `TypeError` on a fake device (Task 6 catch-entry) | ✅ proven by `neiry_bci_provider_device_port_test.dart:151–154` |
| `NeiryBciProvider` implements `IBciDeviceProvider` + `IHeartRateSource` + `IEegBandsSource` + `IEmotionsSource` (one instance satisfies four manager deps) | ✅ `NeiryBciProvider.dart:40` |
| Existing fakes to mine (`FakeDevicePort`, `_ControlledLocatorPort`, `FakeClassifierFactory`/`Set`, `FakeLocatorPort`) | ✅ present in the three port test files |
| `scan()` reaches `requestDevices` on the host VM with no permission mocking | ✅ existing `neiry_bci_provider_locator_port_test.dart:88–116` already drives `scan()` to emission this way |

## Critical Issues

None. The plan is implementable as written.

## Observations (non-blocking)

1. **Host-platform permission skip is implicit but sound.** `scan()` contains `if (Platform.isIOS) … else if (Platform.isAndroid)` (`:119–151`) before `requestDevices`. Under `flutter test` both are false (host VM), so the gate falls straight through with no `permission_handler` mocking — exactly what the existing locator-port test relies on. The plan never states this, but the H1 tasks depend on it. Worth a one-line note in Task 1 so the implementer doesn't waste time mocking permissions, but it is not a defect.

2. **Task 2 ordering (b) — `disconnect()` first, drop during it — is a genuine race, correctly left to the invariant probe.** During `disconnect()`'s in-flight awaits, `_device` is not nulled until `:501`, so an incoming drop's `_onConnectionStatus` sees `_device != null` and schedules a *second* `_teardownAfterUnexpectedDrop`, and both paths can reach `_resetLocatorSession` (`:438` and `:502`) racing on `_locator`. This is precisely the case the orphan invariants (`liveCount ≤ 1`, no replace-without-dispose) are designed to catch; if it goes red the decision rule says fix the gate. The plan handles this correctly — flagging only so the implementer treats a red here as signal, not noise.

3. **Task 3 gating depends on holding the *locator-dispose* completer, not only the device completers.** `_teardownComplete` resolves only when the microtask body finishes, and its last awaited step is `_resetLocatorSession()` → `await _locator.dispose()` (`:360`/`:438`). The plan says "device and locator-dispose `Completer`s held open" — correct; the device completers alone would suffice to keep it pending, but the gated `dispose()` is what lets the test observe the fresh locator appear exactly on completion. The harness in Task 1 must expose a *replaceable* dispose completer on the L0 instance specifically (it is L0, still `_locator` at `:360`, whose dispose is awaited). The plan's `RecordingLocatorPort` per-instance gated dispose covers this; just ensure the test grabs the L0 handle from the registry creation list, not a later one.

4. **Task 5 double-drop relies on the captured subscription still being live.** The second `BciLinkStatus.down` reaches `_onConnectionStatus` only because `_connectionSub` (captured into a local at `:379`, cancelled at `:412` *inside* the still-pending microtask) has not yet been cancelled while teardown is held. This holds as long as the device `stopStream`/`cancel` completers are open. The plan's "fire a second down while the first teardown microtask is in-flight" is consistent with this; the implementer should keep the teardown gated when emitting the second drop.

These are implementation cautions the plan already implies, not corrections.

## Positive Notes

- **Decision rule + churn caveat are precise and prevent the classic false positive** — distinguishing a redundant-but-paired `dispose()`+create (expected, from `disconnect()`'s unconditional `:502` reset) from a true leak (`creates − disposes > 1` or replace-without-dispose). This is the single most error-prone part of characterizing this code and the plan nails it.
- **Assertions are mandated to be behavioral** (dispose/create counts, wait-ordering) and explicitly forbidden from referencing `_teardownComplete` or gate field names, so the suite survives the C1 actor refactor that removes the gate — fulfilling the milestone's stated purpose (it becomes C1's contract).
- **The two genuinely hard wiring traps are pre-solved:** the concrete-`BciDevicesGrpcApi` assignability trap (plan-review #1) and the fresh-device-per-`createDevice` requirement that keeps Task 4's reconnect from hitting closed broadcast controllers (plan-review #3).
- **Scope discipline:** full L1 (thrown `cancel()` after a completed connect) is explicitly deferred to `[[161]]`, and only the no-completed-connect slice is taken here — matching the roadmap's "L1 only partially covered."
- **Determinism note (plan-review #4)** correctly schedules one event-loop turn after emitting the drop before calling `scan()`, since `_teardownComplete` is assigned inside the microtask-dispatched listener.

PLAN_REVIEW_PASS
