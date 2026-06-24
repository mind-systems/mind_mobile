# Plan Review: ModuleInstructionStream readiness-gate and rate-limit tests

**Plan:** `.ai-factory/plans/100-moduleinstructionstream-readiness-gate-and-rate-limit-tests.md`
**Scope:** Test-only plan (no source changes) for `lib/Core/Grpc/ModuleInstructionStream.dart`
**Risk Level:** 🟢 Low

## Verification Summary

Every factual claim in the plan was checked against the actual source and generated proto:

- **Clock injection "ALREADY DONE"** — Confirmed. `_clock` field at line 18, default `DateTime.now` constructor param at line 54, used in `emit()` at lines 93 and 101. No source refactor needed. ✓
- **`_outbox.sort` at line 180** — Confirmed (`_drainOutbox` sorts ascending by `timestamp`). ✓
- **Rate-limit math** — `1000 ~/ 10 = 100 ms` default interval (line 91), drop branch at lines 92–99, `_lastSendTime` set at 101. First post-ready emit has no `_lastSendTime` → never dropped. ✓
- **Readiness gate / outbox buffering** — `_isReady` gate at lines 90/102–104, `_becomeReady`/`_drainOutbox` at 174–185. ✓
- **Reconnect re-arm** — `disconnected` branch (lines 63–72) clears `_isReady`, `_lastSendTime`, `_outbox`, sink; `_openStream` (116–121) resets the same fields. ✓
- **5 s fallback timer** — `_readyTimeout = Duration(seconds: 5)` (line 36), `Timer` armed at 165, `_onReadyTimeout` early-return on `_isReady` (169), ready branch cancels timer (137). ✓
- **error/done paths** — `onError`/`onDone` both call `disconnect()` + `scheduleReconnect()` and reset readiness (148–163). ✓
- **`confirmConnected` once** — `_backoffConfirmed` guard at 126–129. ✓
- **`dispose()`** — cancels timer, connection sub, stream sub, closes sink (107–112). ✓
- **Proto API** — `StreamResponse(ready: StreamReady(maxSamplesPerSecond:))` / `StreamResponse(ack: StreamAck(maxSamplesPerSecond:))`, `StreamSample(sessionId, timestamp: Int64, moduleId, instructionType, data)`, `streamData(Stream, {CallOptions?}) -> ResponseStream<StreamResponse>`, `whichEvent()` / `StreamResponse_Event` enum — all match the plan's harness notes exactly. ✓
- **Test infra** — `fake_async: ^1.3.3` present in `pubspec.yaml`; reference fake `module_state_channel_test.dart` exists with the exact `_FakeClientCall` / `_FakeConnectionManager` patterns the plan cites. ✓
- **`InstructionSample`** fields (`sessionId`, `timestamp:int`, `moduleId`, `instructionType`, `data:Map`) match `_sample(...)` factory and `_toProto`. ✓

No missing steps, wrong codebase assumptions, incorrect file paths, or wrong API usage found. No migrations apply (test-only). No security surface.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** PASS. Test mirrors `lib/Core/Grpc/` under `test/Core/Grpc/`. `ModuleInstructionStream` is explicitly listed as a `Core/Grpc/` component. No boundary impact.
- **Rules (`RULES.md`):** PASS. The stateless-Service and App.dart-infrastructure rules do not apply to a transport-layer unit test.
- **Roadmap (`ROADMAP.md`):** WARN (non-blocking). The plan references a "ROADMAP Test Infra" prerequisite but no roadmap entry is added. This is acceptable for a test-only plan — test coverage is not a `feat`/`fix`/`perf` milestone requiring linkage.

## Minor Suggestions (non-blocking, for the implementer)

1. **Capture `onDone` on the request stream in the fake.** Task 9's case *"should close the request sink on dispose, verified by the captured request stream completing (onDone)"* requires the fake's `streamData` to register `request.listen(sentSamples.add, onDone: …)` and expose that completion (e.g. a `Completer` or bool flag). The harness notes describe recording samples but do not call out this `onDone` seam — add it so the assertion has something to observe.

2. **Dispose in every test to drain the 5 s `_readyTimer`.** Any test that connects but never receives a `ready`/`ack` frame (notably Tasks 2, 3 pre-ready, 4, 7) leaves the real `Timer` from `_openStream` pending. Sending a `ready` frame cancels it (line 137); otherwise only `dispose()` does. The reference test calls `dispose()` at the end of each case — follow that convention uniformly to avoid cross-test timer bleed, especially since rate-limit tests run without `fakeAsync`.

3. **Drain bypasses rate-limit by design — keep assertions consistent.** `_drainOutbox` (179–185) adds straight to the sink and does **not** set `_lastSendTime`. So the first *post-drain* `emit()` still sees `_lastSendTime == null` and is never rate-limited. The plan's Task 3 and Task 5 cases are consistent with this, but the implementer should not assert that drained samples advance the rate-limit window.

These are refinements to the harness notes, not defects in the plan's structure or coverage. The phased breakdown (lifecycle → readiness gate → reconnect → rate-limit → fallback → guards/error → dispose) maps cleanly onto every branch of the source under test.

PLAN_REVIEW_PASS
