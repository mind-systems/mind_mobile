# Plan Review: ModuleStateChannel proto-event tests

**Plan:** `.ai-factory/plans/100-modulestatechannel-proto-event-tests.md`
**Files Reviewed:** plan + `ModuleStateChannel.dart`, `ModuleState.dart`, `ModuleStateEvent.dart`, `ActivityType.dart`, generated proto (`module_state.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`), grpc-5.1.0 `common.dart`, existing tests, note 178
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture** (`ARCHITECTURE.md`): WARN — none. This is a test-only plan adding `test/Core/Grpc/module_state_channel_test.dart`; it touches no production layer and respects the domain/module boundary (the SUT is Core infra). No boundary impact.
- **Rules** (`RULES.md`): WARN — none. The "stateless Service / no StreamController" rule targets module Services, not test fakes; building `StreamController`-backed fakes inside the spec is fine and idiomatic (matches `grpc_connection_manager_backoff_test.dart`).
- **Roadmap** (`ROADMAP.md`): WARN — the plan has no explicit roadmap linkage. It is test-coverage work derived from note 178 (notes 152/153/154/137). Acceptable for a test plan; no milestone entry required.

## Verification of plan assumptions (all confirmed)

- **`ResponseStream` fake mechanism** — confirmed in grpc-5.1.0 `common.dart`: `ResponseStream(this._call) : super(_call.response)`. The channel only calls `response.listen(...)` (`ModuleStateChannel.dart:81`), so a fake `ClientCall` exposing only a `response` getter is sufficient. Plan is correct.
- **`trackActivity` signature** — confirmed: `ResponseStream<StateResponse> trackActivity(Stream<StateRequest> request, {CallOptions? options})`. Positional stream + named `options`, exactly as the plan asserts.
- **`ModuleStateServiceClient`** is a concrete class extending `$grpc.Client` with a `(super.channel, ...)` constructor. The plan correctly uses `implements` + `noSuchMethod` (no superclass constructor invoked, so no real channel needed).
- **Enum names** — all confirmed in `.pbenum.dart`: `RESUMED`, `ABANDONED`, `ACTIVE`, `COMPLETED`, `INTERRUPTED`, `DISCONNECTED`, `ACTIVITY_STATUS_UNSPECIFIED`.
- **`StateResponse_Event` { sessionState, sessionError, notSet }** and `whichEvent()` — confirmed.
- **`StateEvent`** fields `moduleSessionId` / `status` / `isPaused` and **`StateErrorEvent`** `.code` / `.message` — confirmed.
- **Models** — `ModuleStateStatus { idle, active }`, `ModuleState({required moduleSessionId, required status, isPaused=false})`, `ModuleState.initial()`, and the six `ModuleStateEvent` subclasses (`ModuleSessionResumed`/`Abandoned` carry the right shapes) — confirmed.
- **Line citations** in the plan (RESUMED 127-133, ABANDONED 152-154, sessionError 92-96, metadata 75-80, start 165-174, end 189-196, lifecycle 55-114, dispose 230-236, guard 205-211) — all accurate against the current file.
- **Test conventions** (`Future<void>.delayed(Duration.zero)`, `noSuchMethod` fakes, `_make()` record fixture, user builders) — match `grpc_connection_manager_backoff_test.dart` and `meditation_module_state_channel_test.dart`.
- `_events` is a `PublishSubject` (no replay) — the plan correctly instructs subscribing before triggering.

## Advisory notes (non-blocking — clarify during implementation)

1. **Phase 4 (metadata) requires reaching `active` state via a reconnect, not a direct setter.** `currentState` is derived from the private `_state` BehaviorSubject; there is no public way to seed it active. On the *first* connect, `currentState` is always `initial()` (idle, null id) → `options == null`. To exercise the "attach metadata" path the test must: connect (stream #1, null options) → emit an `ACTIVE`/`RESUMED` frame carrying the id → emit `disconnected` then `connected` to re-open (stream #2) → assert stream #2's options. The plan's last Phase-4 case ("recompute metadata on each reconnect") implies this, but the first four cases are phrased as if state can be set directly. Implementer should treat the connect→ACTIVE→reconnect sequence as the precondition for all four.

2. **Phase 5 `end()` forwarding requires non-idle state first.** `end()` early-returns when `currentState.status == idle` (`ModuleStateChannel.dart:190`), so opening a stream and calling `end(...)` alone sends nothing. The session must be driven to `active` (via an `ACTIVE` frame on the live stream) before `end()` will emit a `StateRequest`. Note 178's detailed spec already states "Start a session first" — the plan's summary bullet omits it. `start()` has no such issue (it proceeds from idle).

3. **Per-reconnect call tracking.** As the plan notes, each `connected` transition opens a fresh `trackActivity` call. The fake must keep a list of calls (each with its own `options` + response controller) and the test must emit on the *latest* call's controller. Plan covers this; just reinforcing it is load-bearing for Phases 4, 7, 8.

## Positive Notes

- The fake infrastructure is the only real risk in a test plan, and the plan front-loaded it correctly with verified grpc internals — the `ResponseStream`/`ClientCall` analysis is accurate down to the constructor.
- Test-case naming is behavioral and specific; edge cases (Int64(0) vs unset, empty-string id, repeated-paused no-op, DISCONNECTED ignored, no_active_session silent demote) map exactly to the source branches.
- Correctly isolates the SUT (fake `GrpcConnectionManager` rather than the real one) and reuses established conventions, keeping the spec consistent with the existing suite.

The plan is solid, technically accurate, and implementable as written; the three advisory notes are sequencing clarifications, not corrections.

PLAN_REVIEW_PASS
