# Code Review 2: B1 · Characterization — locator/device races H1 + L2

**Branch:** `phase-55-serialize-bci-lifecycle`
**Scope reviewed:** the only code change in the diff — `test/Bci/neiry_bci_provider_locator_device_races_test.dart` (new, now 833 lines; was 893 in review-1). Other staged files are docs/notes/plans (no code).

**Verification performed (re-run from scratch):**
- `flutter analyze test/Bci/neiry_bci_provider_locator_device_races_test.dart` → **No issues found** ✅
- `flutter test test/Bci/neiry_bci_provider_locator_device_races_test.dart` → **10/10 pass** (green on gate version) ✅
- `flutter test test/Bci/` → **51/51 pass** — no regression ✅
- Re-read the new file in full and re-traced each probe against `NeiryBciProvider.dart` / `BciDeviceManager.dart`.

## Review-1 follow-up — all findings resolved

| # | Review-1 finding | Status in this revision |
|---|---|---|
| 1 (Major) | Task 6 committed exploratory scaffolding + dead `provider`/`registry`/`l0` + comment wall | **Fixed** — replaced with a clean `LocatorPort throwingFactory()` local function + `_ThrowingDeviceLocatorPort`; the narrating comments are gone and the docstring (`:771-775`) now states the actual mechanism concisely. `unused_local_variable` is gone. |
| 2 (Minor) | Unused `SensorSource` import | **Fixed** — import removed (`:34` is now `RrInterval`). |
| 3 (Minor) | `prefer_function_declarations_over_variables` | **Fixed** — now a function declaration `LocatorPort throwingFactory() { … }` (`:778`). |
| 4 (Minor) | Throwing device leaks 3 stream controllers | **Fixed** — `l0.lastCreatedDevice?.closeControllers()` called in cleanup (`:806`). |
| 5 (Minor) | `_ThrowingDeviceLocatorPort` factory bypasses the registry orphan-flag | **Acceptable as-is** — `throwingFactory` still appends directly (`:780`), so the runtime `_orphanDetected` flag is inert for that one test, but `assertNoOrphan()`'s structural loop (`:219-222`) independently verifies every non-final locator was disposed and passes correctly for the L0→L1 case. Non-blocking, as noted in review-1. |

## Independent re-review (this revision)

I re-traced the load-bearing probes against the gate code and found them correct:

- **H1 provider-level (`:508`) and manager-level (`:564`)**: the single `emitConnection(down)` drives both the provider's `_onConnectionStatus` (→ `_teardownAfterUnexpectedDrop`, nulling `_device` and scheduling the gated teardown) and, via the re-emitted `connectionStateStream`, the manager's `_attemptReconnect()`. `scan()` correctly gates on the in-flight teardown: `l0.requestDevicesCallCount == 0` while gated, and only the fresh `L1` receives `requestDevices()` after the teardown completes. Both run deterministically across repeated reasoning of the microtask ordering.
- **L2 pure-drop vs. racing-disconnect split (`:417`/`:441`/`:476`)**: tight one-dispose/one-create asserted only for the pure drop; the racing cases assert only `liveCount ≤ 1` + `assertNoOrphan` + `l0.disposeCount == 1`, correctly tolerating `disconnect()`'s legitimate second paired reset (`:502`). The "churn is not a leak" caveat is honored.
- **Double-drop idempotency (`:684`)**: second `down` is a no-op because `_device` was nulled synchronously in the first `_teardownAfterUnexpectedDrop()` — `createdCount` stays at 1 during flight, then exactly L0→L1 after. Correct.
- **Drop-before-subscribe inert (`:717`)**: `createDevice` gated so `connect()` blocks before `_subscribeDeviceStreams()`; a `down` on a non-subscribed device has no effect; `connect()` finishes with no reset. Correct characterization of a real property.
- **Partial L1 (`:766`)**: default `NeiryClassifierFactory` cast → `TypeError` enters the `:172` catch; `throwOnDispose` makes `dispose()` (`:179`) throw, swallowed by the inner try/catch (`:177-180`); `_resetLocatorSession()` still disposes L0 and creates L1; original `TypeError` rethrows. The dual `disconnectCallCount == 1` / `disposeCallCount == 1` assertion is consistent with `throwOnDispose`-only (disconnect succeeds, dispose increments before throwing).
- **Fakes match real contracts**: `_FakeBciDevicesGrpcApi` / `_FakeNfbCalibrationGrpcApi` `implements` the **concrete** gRPC classes (matching the repository constructors), `SharedPreferences.setMockInitialValues({})` is used, and `connectDevice` is driven to `BciImpedance` (a `BciActive`) before the drop so the reconnect listener fires.
- **Behavioral-assertion contract**: no assertion references `_teardownComplete` or any gate field name — the suite is observable-counts/ordering only, so it will survive the field's removal in the C1 actor refactor.

## Verdict

Done-criterion satisfied (green suite, behavioral contract, no production-code changes), analyzer clean, no regressions, and every review-1 finding addressed. No bugs, security issues, or correctness problems remain.

REVIEW_PASS
