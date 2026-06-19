# Plan Review: Eager-open data tunnels at connect (instruction + biometric)

**Plan:** `48-eager-open-data-tunnels-at-connect-instruction-biometric.md`
**Files reviewed against:** `ModuleInstructionStream.dart`, `BiometricStreamClient.dart`, `ModuleStateChannel.dart`, `GrpcConnectionManager.dart`, `BreathModuleInstructionStream.dart`, `App.dart`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture:** The plan mirrors the established `ModuleStateChannel` lifecycle shape and keeps domain→transport dependency direction intact. The biometric tunnel correctly gains the connection-state source it lacked. No boundary violation. — OK
- **Rules:** Logging stays on `logPrint` (no new log sites added); `App.dart` initializer style preserved per project convention. — OK
- **Roadmap:** Not checked (no blocking criteria requested); change is a behavior refinement under the existing realtime-streaming work (spec note 116). — WARN (no roadmap linkage stated, non-blocking)

## Verified Assumptions (all correct)

- **File paths** — all three target files exist at the stated paths.
- **`ModuleInstructionStream` lazy gate** — `_streamRequested` exists with exactly the assignments the plan calls out: the `connected` case `if (_streamRequested) _openStream()` (line 61), `emit()` `_streamRequested = true;` (line 88), and the `onError`/`onDone` `_streamRequested = false;` (lines 155, 164). Removing the field and these four sites is complete and correct.
- **Readiness gate isolation** — `_isReady`, `_outbox`, `_readyTimer`, `_becomeReady()`, `_drainOutbox()`, `_onReadyTimeout()` are independent of `_streamRequested`; leaving them untouched is correct. `_openStream()` re-arms the gate on every call (lines 110–112), so reconnect correctness holds.
- **`BiometricStreamClient` constructor** — currently takes `grpcStub` + `moduleStateEvents` (lines 52–57); adding `connectionState` is additive. `dart:async` is already imported (line 1), so `StreamSubscription` needs no new import; only the `GrpcConnectionState` import must be added as the plan states.
- **`_ensureSinkOpen` / cooldown / session gate / replay ring** — all present as described (lines 101–156); `_encodeAndAdd` early-returns when `_currentSessionId == null` (lines 170–171), so the "no samples without a session" rule survives eager open.
- **`App.dart` wiring** — `connectionManager` is built at line 206, `biometricStreamClient` at line 215; no reordering needed. Construction style (single-line, no trailing comma) matches surrounding lines.
- **`connectionState` is multi-listener-safe** — it is a `BehaviorSubject.stream` (GrpcConnectionManager lines 15–19), already consumed by `ModuleStateChannel` and `ModuleInstructionStream`. A third subscriber is fine, and BehaviorSubject replays the latest state to the new subscriber, so the biometric client reacts correctly even if `connected` was emitted before it subscribed.
- **No test breakage** — `test/Biometrics/biometric_batcher_test.dart` uses `_FakeBiometricStreamClient implements BiometricStreamClient` (interface, not subclass), so a new required constructor param does not break it. "Testing: no" is acceptable.
- **`flushBuffer` drain hook is safe under eager open** — `_becomeReady()` (via server `ready` or the 5 s timeout) now fires at connect time even with no session. The registered hook is `BreathModuleInstructionStream.flushBuffer`, which flushes an empty `InstructionBuffer` when no session is active — a harmless no-op. No regression.

## Observations (non-blocking)

1. **Biometric tunnel does not self-heal on an isolated stream error while idle.** Unlike `ModuleInstructionStream`/`ModuleStateChannel` — whose `onError`/`onDone` call `_connectionManager.disconnect()` + `scheduleReconnect()`, re-emitting `connected` and reopening every tunnel — `BiometricStreamClient`'s `onError`/`onDone` only call `_teardownSink()` (lines 132–139) and never notify the connection manager. So if the biometric stream alone errors while no session is active, nothing re-triggers `_ensureSinkOpen()` until the next `connected` event or the next `sendBatch`. In practice a real connection drop errors all three streams together and the other tunnels drive a global reconnect, so the biometric sink reopens; the gap is only the isolated-idle-error edge. This is **pre-existing behavior** and the plan does not change it — but the Context line "stay open for the app lifetime" slightly overstates the guarantee for the biometric tunnel. Consider noting this limitation rather than expanding scope.

2. **2 s reopen cooldown can skip a fast eager reopen.** `_teardownSink()` does not reset `_lastOpenAttempt`, so on a reconnect that lands within 2 s of the last open attempt, the connection-state-driven `_ensureSinkOpen()` is a no-op. For the idle (no-session) case this just delays the idle sink reopening; for an active session the next `sendBatch` reopens after the cooldown. The plan explicitly preserves the cooldown, so this is intended — flagged only for awareness, not a defect.

## Positive Notes

- The plan correctly identifies the *minimal* surface: it changes only **when** the sink opens and leaves every gate, cooldown, replay-ring, and readiness mechanism untouched, which is exactly what keeps the risk low.
- It explicitly preserves the synchronous drain-hook ordering and `_openStream()`/`_ensureSinkOpen()` per-open re-arming that prior fixes (notes 44, 114/115) established — no risk of reintroducing the first-frame-lost bug.
- Task dependencies are stated correctly (Task 3 depends on Task 2), and the wiring task accounts for existing construction order in `App.dart`.

The plan is implementable as written; the observations above are awareness items, not required changes.

PLAN_REVIEW_PASS
