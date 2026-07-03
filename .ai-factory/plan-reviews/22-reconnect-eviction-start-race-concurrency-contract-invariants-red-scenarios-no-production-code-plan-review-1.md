## Code Review Summary

**Files Reviewed:** plan `22-…-red-scenarios-no-production-code.md` + targeted codebase (`lib/Core/Grpc/ModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`, `test/BreathModule/breath_module_state_channel_test.dart`, `test/MeditationModule/meditation_module_state_channel_test.dart`, `test/Biometrics/biometric_stream_id_routing_test.dart`, spec note 24, ROADMAP)
**Risk Level:** 🟡 Medium

### Context Gates
- **Roadmap linkage — OK.** Plan title matches `ROADMAP.md:78` ("Reconnect / eviction / start-race concurrency contract (invariants + red scenarios, no production code)"). Governing spec `notes/24-…` exists and the plan encodes its INV/SC catalogue faithfully (note 24 expanded to INV-1…12 / SC-1…7). Impl split (note 20 = eviction/reconnect, note 19 = start-race) matches roadmap lines 79–80. **WARN (non-blocking):** the roadmap line and note 24 both frame the whole set as "red scenarios"; see Critical Issue 1 — a subset is not actually red today.
- **ARCHITECTURE.md — OK.** Test-only milestone; touches nothing under `lib/`, no boundary/dependency impact.
- **RULES.md — OK.** All three rules concern production-code architecture (stateless services, App.dart, constructor DI). No conflict with a `test/`-only deliverable.
- **skill-context — absent.** No `.ai-factory/skill-context/aif-review/SKILL.md`; general rules only.

### Verified assumptions (correct)
- Code anchors cited by the plan are accurate: `onDone`/`onError` both `scheduleReconnect` (`ModuleStateChannel.dart:120-131`), unconditional reopen on `connected` (`:75-76`), shared `bool _isPendingStart` (`:42`), single `start()` guard on `currentState.status == active || _isPendingStart` (`:237`).
- Fake surfaces exist and compile as described: `_FakeModuleStateServiceClient.calls` with per-call `options`/`sentRequests`/`responseCtrl` and `_FakeConnectionManager` counters (`module_state_channel_test.dart:36-91`). Proto supports every frame the harness builds (`StateErrorEvent(code:,message:)`, `StateEvent(status:,moduleSessionId:,isPaused:,activityType:)`, `ActivityStartCmd.clientActivityId`).
- `fake_async` is a real dep (`pubspec.yaml:105`) and the bio red-test precedent uses it (`biometric_stream_id_routing_test.dart:3,101`).
- Adapter constructors match the harness plan: `BreathModuleStateChannel(channel:, stateStream:, instructionStream:, sessionId:, …)` and `MeditationModuleStateChannel(channel:, stateStream:, refId:)`, both typed on the real `ModuleStateChannel` — so wiring the **real** channel (not `_FakeChannel`) type-checks.
- Genuinely-RED scenarios confirmed against current code: INV-1/SC-4 (SUPERSEDED+close still schedules reconnect today), INV-2/SC-6 (reopen on resume today), INV-5/SC-3 (no settling-window eviction today), INV-8 retry / SC-2 (no retry today), INV-11 (no defer today).

### Critical Issues

**1. Several "RED now" scenarios are GREEN against current code when driven through the mandated real `ModuleStateChannel`.**
The hard guard (line 13) requires every test be "genuinely RED (fails against current behaviour)", and note 24's Verify says "Scenarios are RED". But the current single-state + registry code already exhibits the asserted behaviour for the single-practice framings below, so those tests pass today — they don't pin a regression and give note 19/20 nothing to green:

- **INV-7 (Task 3, `plan:73`) — GREEN now.** RESUMED handling already reads `event.isPaused` into both the single-state and the registry entry (`ModuleStateChannel.dart:152-159`, `_upsertRegistryEntry` `:205-214`). A RESUMED breath frame with `is_paused=true` → `childOfType(breath).isPaused == true` today. This is already covered by existing tests (`module_state_channel_test.dart:1190-1218`). Reframe as an explicit GREEN-now guard, or drive it through a reconcile seam that doesn't exist yet (forbidden by line 18).
- **INV-10 / SC-7 (Task 4, `plan:84`) — GREEN now as written.** "Seed a live child via a RESUMED frame, then drive the adapter start → expect no fresh `activityStart`." The RESUMED frame flips `currentState.status` to `active`, so `start()` returns early at `:237` and sends nothing — the desired "adopt, no duplicate" outcome already happens via the single-state guard, not via `childOfType`. The genuinely-red case is the **race** (start fired before the RESUMED lands), which is INV-11. As ordered here it passes today.
- **INV-4 (Task 3, `plan:70`) — green unless carefully framed.** `rootId` is only ever set from ROOT-typed frames (`_handleRootFrame:223-231`); it is never sourced from a child fan-out today, so "rootId from ROOT re-open, never from fan-out" already holds. It is only RED if the assertion targets stale-root eviction on reconnect (registry is *not* cleared on stream close/reopen, so a pre-reconnect `rootId` persists) — assert `rootId` is cleared/replaced on reconnect until the ROOT re-open, not merely that a delivered ROOT frame sets it.

Recommendation: before committing, **run each "RED now" test and confirm it fails**; relabel any that pass as GREEN-now guards (the plan already sanctions this category for INV-1 bare-close / `onError`), or reconstruct them into a genuinely-red ordering/concurrent framing.

**2. Task 5 SC-1 assertion contradicts the plan's own hard guard.**
Task 5 (`plan:89`) says "assert breath's pending is cleared but meditation's is NOT (per-type pending independence)." Per-type pending is a private field, and line 18 explicitly forbids asserting on "per-type pending fields." As written this steers the implementer toward the forbidden (or non-compiling) assertion. Re-express purely through the wire: e.g. "both breath's and meditation's `activityStart` reach the wire" (today only breath's does — the second is dropped at `:237` because `_isPendingStart` is already set → genuinely RED and observable). Fix the wording so the deliverable matches its own guard.

### Minor Issues / Suggestions

- **Task 1 harness — two required inputs omitted from the description (`plan:56`).** The real `ModuleStateChannel` constructor requires `authStream` (an `AuthState` stream) and `BreathModuleStateChannel` requires an `instructionStream`. `wireConcurrent` must supply both (a `StreamController<AuthState>` and a fake instruction stream, per the existing `_make` fixtures). Also: the harness must push `connected` **before** any adapter emits its running/active state, otherwise `channel.start` is silently dropped by the null-sink guard (`_sendSessionRequest:292-298`) and the "start reached the wire" assertions never fire. Worth pinning so the implementer doesn't chase a phantom.
- **fakeAsync vs microtask-pump mixing.** The plan mandates `fake_async` for timing (good), but every existing channel/adapter test pumps with `await Future<void>.delayed(Duration.zero)`, which cannot be used inside `fakeAsync`. Inside the `fakeAsync` zone each `responseCtrl.add(...)` / state emission must be followed by `async.flushMicrotasks()` (as the bio precedent does, `biometric_stream_id_routing_test.dart:116-123`). Call this out so the two pumping styles aren't mixed within one test.
- **INV-1/SC-4 vs INV-2/SC-6 counter bookkeeping (Task 2, `plan:63,66`).** After SUPERSEDED+close, `scheduleReconnect` is already `1` today (from `onDone:126-131`), so "scheduleReconnect stayed 0" is false at the point of app-resume — the test is red, but for the combined reason (no-yield-on-superseded-close *and* no-reopen-on-resume). Keep the two expectations in separate `test()`s or assert the delta from a captured baseline so a future reader can tell which half regressed.

### Positive Notes
- Invariant catalogue is transcribed verbatim from the governing spec and correctly split by greening note — the "write them down" deliverable is well-scoped and durable.
- Strong discipline on the hard guards: real-channel/real-adapter stateful doubles (m36), the copy-not-import fake convention, the single `skip:`-annotated seam for the one not-yet-existing symbol (`takeOverHere()`, INV-3), and the explicit "do not assert on `_yielded`/`AllSessionsReset`/per-type pending" list — these are exactly the right constraints to keep the suite compiling and meaningful.
- Code-anchor references (`:126-131`, `:42`, `:75-76`) are all accurate — the plan was written against the real file, not a guess.
- Commit plan is coherent and matches the task phasing.

Overall: the plan is well-grounded and mostly correct; the blocking gap is that the "red scenarios" deliverable includes scenarios that are already green today (Critical Issue 1) plus one guard-violating assertion (Critical Issue 2). Address both — and empirically confirm each red test fails first — before implementation.
