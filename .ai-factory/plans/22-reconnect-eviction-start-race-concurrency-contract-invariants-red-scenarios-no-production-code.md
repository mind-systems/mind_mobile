# Plan: Reconnect / eviction / start-race concurrency contract (invariants + red scenarios, no production code)

## Context
Lay down — before either impl — the executable contract for Phase 64's shared reconnect/reconcile surface: the invariants of eviction/close-classification, reconnect/reconcile, and the start-race, plus RED scenarios driven by the breath + meditation adapters concurrently. This milestone writes tests and the written invariant list only; note 20 greens the eviction/reconnect half, note 19 greens the start-race half.

## Settings
- Testing: no (the RED scenario tests ARE the deliverable — do not add meta-tests on top)
- Logging: minimal
- Docs: no (realtime docs are Phase 65 / note 21 — do not touch `docs/`)

## Hard guards (apply to every task)
- **No production code.** Do not edit anything under `lib/`, do not touch `.proto` files, do not run `gen_proto.sh` or `build_runner`. Only files under `test/` are created/modified.
- **Empirically confirm RED before committing.** Every test tagged `RED now` MUST fail when run against the current code (`flutter test <file>` at `/usr/local/bin/flutter`). If one passes, it is not pinning a regression — relabel it a `GREEN-now guard` (the plan already sanctions that category) or reconstruct it into a genuinely-red ordering/concurrent framing. Do not ship a "RED" label on a test that passes today.
- **Assert against the existing observable surface** so every test compiles today and is genuinely RED (fails against current behaviour), not a compile error:
  - `_FakeConnectionManager` counters — `scheduleReconnectCount`, `disconnectCount`, `confirmConnectedCount` (pattern in `test/Core/Grpc/module_state_channel_test.dart:70-91`).
  - The fake `ModuleStateServiceClient.calls` list — reopen count + captured `CallOptions` metadata (`module-session-id` header) + captured `sentRequests` (to read `client_activity_id` / `session_id` off the wire) (pattern `:36-66`).
  - `ModuleStateChannel` public getters — `rootId`, `childOfType(type)`, `isConnected`, `currentState`, emitted `ModuleStateEvent`s.
  - Adapter observable behaviour — a re-armed adapter re-sends `start`; an adopted child sends no fresh `start`.
- **Do NOT assert on symbols that do not exist yet** (`_yielded`, `takeOverHere()`, `AllSessionsReset`, per-type pending fields). Prove each invariant through the observable surface above instead. The single invariant that genuinely needs a not-yet-existing public entry point (`takeOverHere()`) is captured as a `skip:`-annotated test carrying the expectation for note 20 to un-skip — see Task 3.
- **Stateful doubles, not stubs (m36).** Latch/flag/pending/registry state must be exercised through a real `ModuleStateChannel` + real adapters wired to the fake gRPC service — never a pass-through fake that hardcodes the answer. A pass-through would mask exactly the silent regressions this contract guards.
- **Pumping style — `fakeAsync` only, no `Future.delayed`.** All timeout / settling-window / backoff timing uses `package:fake_async` (`fakeAsync` + `async.elapse`). Inside the `fakeAsync` zone, follow every `responseCtrl.add(...)` / state-controller emission with `async.flushMicrotasks()` — NEVER `await Future<void>.delayed(Duration.zero)` (the microtask-pump style used by the existing channel/adapter tests cannot run inside `fakeAsync`). Mirror the bio precedent `test/Biometrics/biometric_stream_id_routing_test.dart:116-123`.
- Every test carries a one-line `RED now / GREEN under note 19|20` (or `GREEN-now guard`) annotation and cross-references its invariant id (INV-*) / scenario id (SC-*) — mirror the annotation style in `biometric_stream_id_routing_test.dart:87-133`.

## Invariant / scenario catalogue (the "write them down" deliverable — encode verbatim in Task 1)
Eviction / close classification (note 20):
- INV-1 Yield **iff** `session_error{code:'CONNECTION_SUPERSEDED'}` was seen on this stream before close. Bare graceful `onDone` (no code) → reconnect + reconcile. `onError` → reconnect.
- INV-2 The yield latch gates stream reopen — a connection-manager reopen (connectivity / app-resume / auth) while yielded must NOT re-take the session.
- INV-3 `takeOverHere()` clears the latch and reopens; the takeover receives a clean **root** frame, **no** child frames.

Reconnect / reconcile (note 20):
- INV-4 `rootId` is sourced from the RootStateChannel ROOT re-open, never from the reconnect fan-out (which carries no root frame). A stale pre-reconnect `rootId` must not silently persist across the reconnect until that ROOT re-open lands.
- INV-5 Registry rebuilt by reconcile-by-arrival from per-child RESUMED frames; a cached child with no arriving frame within the settling window is treated as gone.
- INV-6 Global-reset-then-adopt ordering: an `{abandoned}` reset is applied before a subsequently-minted root repopulates the registry (idempotent).
- INV-7 Resumed children adopt their real `is_paused` from the RESUMED frame.

Start-race (note 19):
- INV-8 Retry a pending start **only** while unconfirmed → no duplicate.
- INV-9 Retry reuses the **same** `client_activity_id`; never regenerate.
- INV-10 Before sending a fresh start, adopt an already-live child of that type (`childOfType`) — and a live child of a *different* type must NOT suppress a start of an un-started type.
- INV-11 Within the settling window after reconnect, defer the adopt-vs-new decision until reconcile completes.
- INV-12 Timings: confirm timeout 5s, max 2 retries (3 attempts total), settling window 3s.

Red scenarios, driven by breath + meditation concurrently (note 24 §Red scenarios):
- SC-1 two concurrent starts · SC-2 start-then-drop-before-ACTIVE · SC-3 reconnect-with-both-live (reconcile both) · SC-4 SUPERSEDED mid-session · SC-5 bare close mid-session · SC-6 app-resume while yielded · SC-7 app-restart mid-start (adopt on resume).

## Tasks

### Phase 1: Contract foundation & shared harness

- [x] **Task 1: Shared stateful-double harness + written invariant catalogue**
  Files: `test/Core/Grpc/Support/reconnect_concurrency_harness.dart`
  Create a self-contained support file (fakes copied in the style of `test/Core/Grpc/module_state_channel_test.dart:18-91`, not imported from other test files):
  - A **library-level doc comment** that writes down INV-1…INV-12 and SC-1…SC-7 verbatim (the catalogue above), each with its RED-now / GREEN-under-note / GREEN-now-guard annotation. This is the durable "write them down" artefact.
  - `FakeModuleStateServiceClient` — records every `trackActivity` call with its `CallOptions` (to read the `module-session-id` header), captures `sentRequests` per call, and exposes a per-call `responseCtrl` to inject `StateResponse` frames.
  - `FakeConnectionManager` — broadcast `connectionState` plus `confirmConnectedCount` / `disconnectCount` / `scheduleReconnectCount`, and a helper to push `connected` / `disconnected` (used to simulate app-resume and reconnect).
  - Frame-builder helpers producing proto `StateResponse`s: ROOT `ACTIVE`/`RESUMED` frame, child `ACTIVE` frame, child `RESUMED` frame with an explicit `is_paused`, `session_error{CONNECTION_SUPERSEDED}`, and a bare stream close (`responseCtrl.close()`).
  - A `wireConcurrent(...)` helper that builds ONE real `ModuleStateChannel` on the fake service + fake connection manager and wires BOTH a real `BreathModuleStateChannel` and a real `MeditationModuleStateChannel` to it (driving each via its own state `StreamController`), returning the channel, both adapters, both state controllers, and the fakes. **Required inputs the helper must supply** (verified against the real constructors): `ModuleStateChannel` needs `authStream` → back it with a `StreamController<AuthState>`; `BreathModuleStateChannel` needs `instructionStream` → supply a fake `BreathModuleInstructionStream` (recorder, style of `breath_module_state_channel_test.dart:60-72`); `MeditationModuleStateChannel` needs only `channel` + `stateStream` + `refId`. Model the adapter wiring on `test/BreathModule/breath_module_state_channel_test.dart` and `test/MeditationModule/meditation_module_state_channel_test.dart` but bind to the **real** `ModuleStateChannel`, not the `_FakeChannel`, so the registry / pending / close-classification state is real.
  - **Ordering pin:** the helper (or each test) must push `GrpcConnectionState.connected` and flush **before** any adapter emits a running/active state — otherwise `channel.start` is silently dropped by the null-sink guard (`ModuleStateChannel.dart:292-298`) and the "start reached the wire" assertions never fire.

### Phase 2: Eviction / close-classification & reconcile red scenarios (note 20 greens)

- [x] **Task 2: Close-classification & latch red scenarios** (depends on Task 1)
  Files: `test/Core/Grpc/reconnect_eviction_contract_test.dart`
  RED scenarios over the eviction/close surface, asserted via connection-manager counters and reopen count. **Keep the two failure modes in separate `test()`s (or assert deltas from a captured baseline)** so a reader can tell which half regressed — after SUPERSEDED+close `scheduleReconnect` is already `1` today from `onDone`, so a combined assertion is ambiguous:
  - INV-1 / SC-4: inject `session_error{CONNECTION_SUPERSEDED}` then close the stream → expect NO `scheduleReconnect` (RED now — current `onDone` always schedules a reconnect, `ModuleStateChannel.dart:126-131`).
  - INV-1 / SC-5: bare `onDone` close with no preceding code → expect `disconnect` + exactly one `scheduleReconnect` (GREEN-now guard — pins the reconnect-on-bare-close half so the impl can't over-yield).
  - INV-1: `onError` (transport drop) → expect reconnect (GREEN-now guard).
  - INV-2 / SC-6: after SUPERSEDED+close, capture the fake service `calls.length` baseline, push `connected` again (app-resume), flush → expect NO new `trackActivity` call opened (delta == 0) and `scheduleReconnect` unchanged from its post-close value (RED now — current code reopens unconditionally on `connected`, `:75-76`).

- [x] **Task 3: Reconcile & takeover red scenarios** (depends on Task 1)
  Files: `test/Core/Grpc/reconnect_eviction_contract_test.dart` (extend Task 2's file)
  - INV-4 (stale-root framing — this is the genuinely-red angle): drive a live ROOT (rootId set), then simulate a reconnect (stream close → reopen) with server memory lost and deliver only per-child RESUMED frames (no ROOT frame). Assert `rootId` does NOT still resolve to the pre-reconnect root and is NOT derived from the child fan-out — it must be null/absent until a subsequent ROOT re-open frame sets it (RED now — the registry is not cleared on close/reopen `_closeSessionStream:136-141`, so the stale `rootId` silently persists). Then deliver the ROOT re-open frame → `rootId` restored.
  - INV-5 / SC-3: reconnect with two locally-cached children; deliver a RESUMED frame for only one within the settling window; after the 3s window (`async.elapse`) assert the arrived child survives in the registry and the silent one is treated as gone (RED now — no settling-window eviction today).
  - INV-6: apply an `{abandoned}` global reset, then a freshly-minted ROOT frame arrives → assert the registry ends with exactly the new root and no stale children (idempotent ordering); assert reset-then-adopt does not double-populate (RED now).
  - INV-7: **GREEN-now guard** (not RED — RESUMED already reads `event.isPaused` into the registry entry, `ModuleStateChannel.dart:152-159` / `_upsertRegistryEntry:205-214`, and is covered at `module_state_channel_test.dart:1190-1218`). Pin it as a guard: a child RESUMED frame with `is_paused = true` → `childOfType(type).isPaused == true`, so the note-20 reconcile rewrite cannot regress paused-adoption. Label GREEN-now guard, not RED.
  - INV-3 (takeover): `skip:`-annotated test documenting the expectation — after eviction, `takeOverHere()` reopens the stream and the next frame is a clean ROOT RESUMED with no child frames. Reason string references note 20 (adds `takeOverHere()`); note 20's impl un-skips it. This is the ONE invariant that needs a not-yet-existing public seam.

### Phase 3: Start-race red scenarios (note 19 greens)

- [x] **Task 4: Single-practice start-race red scenarios** (depends on Task 1)
  Files: `test/Core/Grpc/start_race_contract_test.dart`
  RED scenarios via captured wire `sentRequests` under `fakeAsync`:
  - INV-8 / INV-9 / SC-2: send `start`, drop before any confirming ACTIVE frame, `async.elapse(5s)` → expect a second `activityStart` on the wire carrying the **same** `client_activity_id` (RED now — no retry, only one start; assert the id equals the first start's id).
  - INV-8: after a confirming ACTIVE/RESUMED frame lands, `async.elapse(10s)` → expect NO retry (GREEN-now guard against duplicate — the confirming frame already flips `_isPendingStart` false today; pins that the note-19 retry does not fire once confirmed).
  - INV-12: after retries exhaust (2 retries / 3 total attempts over the 5s timeout), assert no further `activityStart` is sent (RED now — bounded retry does not exist).
  - INV-10 / SC-7: **same-type adopt is GREEN-now guard, cross-type suppression is the RED case.**
    - GREEN-now guard: after an app-restart the old child RESUMED lands (single-state → active), then the same-type adapter drives start → no fresh `activityStart` (today `start()` early-returns at `:237`; pins no-duplicate-on-adopt).
    - RED now: with a live **meditation** child (single-state active), drive the **breath** adapter's start → expect breath's `activityStart` to reach the wire (RED now — the shared single-state guard at `:237` wrongly suppresses it because `currentState.status == active`; GREEN under note 19's per-type adopt/pending).

- [x] **Task 5: Concurrent breath+meditation start-race & settling-window red scenarios** (depends on Task 1)
  Files: `test/Core/Grpc/start_race_contract_test.dart` (extend Task 4's file)
  Drive both adapters concurrently through `wireConcurrent(...)`. **Assert purely on the wire — never on per-type pending fields (guard):**
  - SC-1 / INV-8: start breath and meditation concurrently (both un-started) → assert BOTH breath's and meditation's `activityStart` reach the wire (RED now — only breath's is sent; the second is dropped at `:237` because the shared `_isPendingStart` / single-state guard is already set → genuinely RED and observable via `sentRequests`).
  - INV-11 / SC-3: within the 3s settling window after a reconnect, tap start on an adapter whose old child is about to resume; assert the start is DEFERRED (no `activityStart` on the wire yet); after the window with the RESUMED frame arrived, assert the child is adopted and no duplicate start went out (RED now — no defer today).
  - INV-11: symmetric case — settling window elapses with NO RESUMED frame for that type → assert the deferred start IS sent after the window (deferral releases, not drops; RED now).

## Commit Plan
- **Commit 1** (after Task 1): "Add reconnect/eviction/start-race concurrency contract harness and invariant catalogue"
- **Commit 2** (after tasks 2-3): "Add eviction, close-classification and reconcile red scenarios"
- **Commit 3** (after tasks 4-5): "Add start-race and concurrent-caller red scenarios"
