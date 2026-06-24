# Plan Review: BiometricStreamClient readiness-gate, sessionConfirmed, and cooldown tests

**Plan:** `100-biometricstreamclient-readiness-gate-sessionconfirmed-and-cooldown-tests.md`
**Scope:** Test-only — adds `test/Biometrics/biometric_stream_client_test.dart`. No production code changes.
**Risk Level:** 🟢 Low

## Verification performed

Cross-checked every line reference and API claim against the actual sources:

- `lib/Biometrics/BiometricStreamClient.dart` — all cited line ranges are **accurate**: constructor lines 61–82 with injectable `clock` (default `DateTime.now`) and `readyTimeout` (default 5 s); `sendBatch` gate 110–115; `_onLifecycleEvent` 86–106; connection `disconnected` clears `_sessionConfirmed` 75–77; cooldown guard 131–138; `_isReady = false` reset on open 140; `ready` drain 151–157; `_teardownSink` 188–195; `_encodeAndAdd` buffering 199–213; `_enqueueReplay` drop-oldest 236–241; fallback timer 177–185; `_replayRingMax = 75` line 34. ✔
- `ModuleStateEvent.dart` — sealed hierarchy and constructors match (`ModuleSessionStarted({moduleSessionId})`, `ModuleSessionResumed({moduleSessionId})`, `ModuleSessionPaused`, `ModuleSessionUnpaused`, `ModuleSessionEnded`, `ModuleSessionAbandoned`). Note the unpause event is `ModuleSessionUnpaused` (the plan uses this correctly in Task 2). ✔
- Generated client — `ModuleBiometricStreamServiceClient.streamData(Stream<BioSampleBatch>)` returns `$grpc.ResponseStream<BioStreamResponse>` (line 36). ✔
- `BioSampleBatch(samples:)`, `BioSample`, `BioStreamResponse` oneof (`ack` / `error` / `ready` via `whichEvent()`), `BioStreamReady`, `BioStreamResponse_Event` — all confirmed. ✔
- Test conventions (`fakeAsync`, `_sample` helper, `flushMicrotasks`/`Future.delayed(Duration.zero)`) match `biometric_batcher_test.dart`. ✔

The plan is logically sound: I traced each task's state transitions through the source (session gate, cooldown reset on start/resume, re-gate on reconnect, drop-oldest at cap 75, FIFO drain, fallback auto-drain) and they all hold.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`, present):** No boundary impact — test-only change in the Biometrics layer. No findings.
- **Rules (`.ai-factory/RULES.md`, present):** Rules target production architecture (stateless module services, App.dart purity, constructor injection). None apply to a test file. No violations.
- **Roadmap (`.ai-factory/ROADMAP.md`, present):** This is a testing milestone in the established `#100` coverage series (siblings: #37 batcher/RR, #34, #100-bcidevicemanager, etc.). Not a `feat`/`fix`/`perf` change requiring roadmap linkage. No finding. — `WARN`-level only: plan has no explicit ROADMAP line reference, which is acceptable for a test-coverage task.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** absent — no project-specific review overrides to apply.

## Findings

All findings are clarifications/warnings — none block implementation.

### 1. (WARN) Task 7 log-capture mechanism is mis-described — no such harness exists
The plan says to capture the readiness-timeout warning "via the project's log capture harness used by other tests, or a `runZoned`/`logPrint` spy." There is **no existing log-capture harness** in `test/` (the only test mentioning `logPrint` is `neiry_bci_provider_full_teardown_test.dart`, and only in a comment — it does not capture output).

`logPrint` (`packages/mind_logger/lib/src/logger.dart`) routes to Flutter's `debugPrint` (when `logToConsole`) and `observeSink` (when `logToObserver`). In `kDebugMode` tests both are active. Implications:
- **`observeSink` is safe** — it forwards to `log()`, which is "silently ignored (never throws)" before SDK `init`, so it is a no-op in unit tests. Good.
- **A `runZoned` print spy is unreliable** — Flutter's default `debugPrint` is `debugPrintThrottled`, which defers output through a `Timer`. Under `fakeAsync` (which Task 7 requires) the throttled output will not surface synchronously at the assertion point.
- **Recommended approach:** override the global `debugPrint` with a synchronous collector and restore it in `tearDown`, e.g. `final logs = <String?>[]; final original = debugPrint; debugPrint = (m, {wrapWidth}) => logs.add(m); addTearDown(() => debugPrint = original);`. This captures `logPrint` output deterministically and is `fakeAsync`-safe.

The implementer should be steered to this pattern rather than the suggested spy/harness.

### 2. (WARN) Task 1 "drive ready" presupposes an already-open stream
Test case *"should send after ModuleSessionStarted confirms the session — emit `ModuleSessionStarted`, drive ready, then `sendBatch`"*: a `ready` frame can only be injected **after** the outbound stream is open, because the response stream does not exist until `_ensureSinkOpen()` runs (triggered by a `sendBatch` or a `GrpcConnectionState.connected`). Lifecycle `ModuleSessionStarted` alone does **not** open the sink.

Correct ordering must be one of: (a) `started` → `connected` (opens stream) → inject `ready` → `sendBatch` reaches sink directly; or (b) `started` → `sendBatch` (opens + buffers the sample) → inject `ready` (drains buffered sample to sink). Worth making the open-before-ready ordering explicit so the implementer doesn't try to emit `ready` against a null response stream.

### 3. (WARN) Fake stub must support multiple stream opens
Tasks 4 and 6 reopen the stream (teardown → reopen), so `streamData` is called more than once. The "Fakes" section describes the fake mostly in the singular (a single captured input stream, a single frame injector). The fake must return a **fresh** `_FakeResponseStream` per `streamData` call and expose the **per-open** input stream and frame sink (e.g. lists indexed by open count), so a test can assert against the second stream after a reconnect. Make this explicit.

### 4. (NIT) Imprecise wording that could mislead
- "inject a `BioStreamResponse.ready` frame" — there is no `BioStreamResponse.ready` factory; construct `BioStreamResponse(ready: BioStreamReady())`.
- Task 3 "(sink opens via cooldown path)" — the sink actually opens because `_lastOpenAttempt` is `null` after `ModuleSessionStarted` (cooldown reset), so the first `sendBatch`'s `_ensureSinkOpen` opens immediately. The phrase reads as if the cooldown *causes* the open; it's the cooldown *reset* that permits it.
- Task 6 cooldown-window test says "emit connected (**or sendBatch**)". After `disconnected`, `_sessionConfirmed = false`, so a `sendBatch` returns at the line-111 gate and never reaches `_ensureSinkOpen` — it would pass the assertion for the wrong reason. Use `GrpcConnectionState.connected` to genuinely exercise the 2 s cooldown guard.

### 5. (NIT) Pre-ready buffering assertions depend on the fallback timer not firing
With `readyTimeout` shortened to 10 ms, any test asserting "buffered, not sent" (Tasks 3, 5) must run under `fakeAsync` **without** elapsing past the timeout (the plan's timing note already mandates `fakeAsync`, so this is covered). If any such assertion is instead written as a real `async`/`await` test, use a long `readyTimeout` so the fallback drain doesn't race the assertion. Worth a one-line caution.

## Positive notes

- Line-accurate source mapping for every task — rare and valuable; makes the plan directly executable.
- Correctly leverages the already-merged test-infra seams (`clock`, `readyTimeout`) and explicitly forbids re-refactoring production code.
- Right instinct on the key invariant: assert through observable effects (sink output, `streamData` call count, logged warning) rather than reaching into private fields — this is called out explicitly.
- The cap/drop-oldest test (76 → retain ts 2..76) and the FIFO-drain assertions are precisely specified.
- Task 7's "should NOT fire the fallback when ready arrives first" correctly notes the timer is cancelled at 153–154 and the body is double-guarded by `if (!_isReady)`.

## Conclusion

The plan is solid, accurate, and implementable as written. All findings are clarifications/warnings — the most actionable being the Task 7 log-capture mechanism (override `debugPrint`, not a print-zone spy). None invalidate the plan structure or its test logic.

PLAN_REVIEW_PASS
