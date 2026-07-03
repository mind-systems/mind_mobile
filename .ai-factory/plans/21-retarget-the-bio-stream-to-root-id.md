# Plan: Retarget the bio stream to `root.id`

## Context
Bio samples must land on the shared **root** timeline, not the current activity: `BiometricStreamClient` should source its `session_id` from `root.id` (via `RootStateChannel` / registry) and keep flowing when a child ends, stopping only when the root is gone. Phase/instruction markers stay on the child id — untouched. This turns the note-23 RED id-routing tests green.

## Settings
- Testing: yes (one reconnect regression test — see Task 3)
- Logging: minimal
- Docs: no

## Key findings (from codebase exploration)

- The root-id seam already exists as a no-op: `BiometricStreamClient` accepts an optional `Stream<String?>? rootIdChanges`, subscribes it via `_rootIdSub`, and routes to `_onRootIdChanged` (currently empty). Cancellation is already wired in `dispose()` (`BiometricStreamClient.dart:29,66,87,116,132`).
- Today `_currentSessionId` / `_sessionConfirmed` are driven by `_onLifecycleEvent` (child lifecycle): set on `ModuleSessionStarted`/`Resumed` (`:94-101`), **cleared** on `ModuleSessionEnded`/`Abandoned` (`:106-111`). The send gate is `:121`; the disconnect path clears `_sessionConfirmed` (`:79`).
- **Two id sources must stay decoupled.** Phase samples go through a *separate* path — `BreathModuleStateChannel` → `BreathModuleInstructionStream.sendSample(sessionId,…)` → `ModuleInstructionStream` — and carry the **child** id. This never touches `BiometricStreamClient`. Do **not** modify it.
- **Constraint from the golden-master test.** `test/Biometrics/biometric_stream_client_test.dart` (explicitly "never edited", per note 23) constructs the client **without** `rootIdChanges` and asserts lifecycle-driven ids (`s1`, cooldown reset on `Started`, gate on disconnect/resume, and specifically "drop sendBatch after disconnect clears session confirmation"). The note-23 routing test `test/Biometrics/biometric_stream_id_routing_test.dart` constructs it **with** `rootIdChanges` and asserts `root.id` wins even after a later `ModuleSessionStarted(child-A)`. → The client must **switch sourcing mode**: when `rootIdChanges` is injected, lifecycle events no longer drive the bio id; when it is absent, the legacy lifecycle behavior is preserved intact.
- The registry stream (`SessionRegistry.rootIdChanges` → surfaced by `ModuleStateChannel.rootIdChanges` and `RootStateChannel.rootIdChanges`) is a seeded, `.distinct()` `String?` stream: `null` when no root, the root id when open. A late subscriber gets the current value immediately.
- **Reconnect hazard (from plan review 1 — must be handled here).** The root id is **idempotent per user** and the stream is `.distinct()`. On a transient gRPC reconnect, `ModuleStateChannel` does not clear the registry, so `RootStateChannel` re-sends `startRoot()` and the server's ROOT frame re-adds the *same* `root.id` — the `'root-1' → 'root-1'` transition is absorbed by `.distinct()` and `_onRootIdChanged` is **never re-entered**. Therefore, in root-sourced mode, nothing re-arms `_sessionConfirmed` after the disconnect path clears it, and bio would silently stop for the rest of the session (recovering only across a full logout/login that emits a real `null`). A transient reconnect is *not* "root gone." Root liveness — not the transport — must be the gate in root-sourced mode.
- `App.dart:234` builds `BiometricStreamClient` without `rootIdChanges`; `rootStateChannel` is already constructed at `:225` (before the client), exposing `rootIdChanges`.
- **`SESSION_NOT_FOUND` needs no code change.** Late phase samples are already dropped silently — `ModuleInstructionStream` logs the `error` frame and does not tear down or surface it (`ModuleInstructionStream.dart:142-143`). The guard test `module_instruction_stream_test.dart` "late SESSION_NOT_FOUND is swallowed" is already GREEN. Just do not regress it.

## Tasks

### Phase 1: Retarget bio sourcing

- [x] **Task 1: Source the bio session id from `root.id` in `BiometricStreamClient`**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  - **Add `final bool _rootSourced` initialized in the constructor initializer list** — `: _rootSourced = rootIdChanges != null, _grpcStub = grpcStub, ...` (a `final` instance field cannot be assigned in the body; do **not** use `late final` or drop `final`).
  - **Implement `_onRootIdChanged(String? rootId)`:**
    - When `rootId != null`: `_currentSessionId = rootId`, `_sessionConfirmed = true`, `_lastOpenAttempt = null` (re-arm the reopen cooldown so a fresh root can open the stream immediately).
    - When `rootId == null` (root gone / global reset): `_currentSessionId = null`, `_sessionConfirmed = false`, `_lastOpenAttempt = null`, and `_replayRing.clear()` (drop buffered samples — they belong to a dead root). Do **not** tear down the sink here; leave sink lifecycle to the connection-state path.
  - **Guard `_onLifecycleEvent` so it no longer drives the bio id when root-sourced:** add `if (_rootSourced) return;` at the top of the method, leaving the existing `switch` (Started/Resumed set, Ended/Abandoned clear, cooldown reset) untouched for the legacy no-`rootIdChanges` construction used by the golden-master test.
  - **Close the reconnect gap: do not clear `_sessionConfirmed` on disconnect in root-sourced mode.** In the `connectionState` listener's `GrpcConnectionState.disconnected` case (`:77-79`), guard the `_sessionConfirmed = false` clear with `if (!_rootSourced)`. Keep `_teardownSink()` unconditional (the sink must still tear down on disconnect and reopen on `connected`). Rationale: in root-sourced mode `_sessionConfirmed` tracks *root known*, set/cleared solely by `_onRootIdChanged`; the transport dropping is not "root gone," and because the idempotent root id re-emission is absorbed by `.distinct()`, nothing would re-confirm it otherwise. In legacy mode (`_rootSourced == false`) the clear still runs, preserving the golden-master "drop sendBatch after disconnect" behavior.
  - Keep the send gate at `:121` (`_currentSessionId == null || !_sessionConfirmed`) exactly as is — "root id known" is now the precondition. Do not touch the encode path (`:210-245`), replay-ring cap, readiness timer, or the `_teardownSink()` call on disconnect.
  - **Correct the class docstring (`:14-24`).** It currently claims "current-module-session gating" and "Session ended / abandoned clears the ring" — both false in root-sourced mode (id tracks the root; a child end no longer clears). Touch these two lines so the comment reads truthfully (id is sourced from `root.id`; cleared only when the root is gone). One-line hygiene fix; does not expand Docs scope.
  - Guards: do **not** touch the phase/instruction path or `BreathModuleStateChannel` (bio = root, phases = child; conflating them corrupts the instruction timeline). Do not change `ModuleInstructionStream` error handling (`SESSION_NOT_FOUND` already swallowed). Proto is unchanged — only which id fills `session_id`.
  - Result: `biometric_stream_id_routing_test.dart` goes green; `biometric_stream_client_test.dart` (legacy mode, no `rootIdChanges`) stays green.

- [x] **Task 2: Wire `rootIdChanges` into the client in `App.dart`** (depends on Task 1)
  Files: `lib/Core/App.dart`
  At the `BiometricStreamClient(...)` construction (`:234`), pass `rootIdChanges: rootStateChannel.rootIdChanges` (already available from `:225`). This flips production to root-sourced mode; bio now tags samples with `root.id` and survives child ends, clearing only when the root is gone.

### Phase 2: Regression coverage

- [x] **Task 3: Add the missing reconnect regression test** (depends on Task 1)
  Files: `test/Biometrics/biometric_stream_id_routing_test.dart`
  Add a test — "bio keeps flowing under root.id across a disconnect/reconnect (no rootIdChanges re-emission)" — that reproduces the reconnect hazard the four existing routing tests miss:
  - Construct with `rootIdChanges`, emit `'root-1'` once, then drive a full send so a batch flows under `'root-1'` (open stream → `injectReady` → assert `sessionId == 'root-1'`).
  - Drive `connectionCtrl.add(GrpcConnectionState.disconnected)` then `GrpcConnectionState.connected` **without** re-emitting on `rootIdCtrl` (this is the key: `.distinct()` would suppress a redundant re-emit in production, so the test must not re-emit either).
  - **The test MUST inject a custom `clock` and advance it > 2 s between teardown and reopen** — this is a requirement, not optional. `_clock` defaults to `DateTime.now`, which `fakeAsync` does not freeze; the first send set `_lastOpenAttempt`, so on reconnect `_ensureSinkOpen` (`:145-148`) is cooldown-blocked and no fresh stream opens, causing the assertion on `stub.latest`/`connections.last` to fail or crash. Mirror the golden-master reconnect test (`biometric_stream_client_test.dart:494-553`): pass `clock: () => fakeNow`, then `fakeNow = fakeNow.add(const Duration(seconds: 3))` + `async.elapse(const Duration(seconds: 3))` after `disconnected`.
  - `sendBatch` again, `injectReady` on the newly opened connection, and assert a batch still flows under `'root-1'` (i.e. `_sessionConfirmed` was not stuck `false`).
  - Mirror the existing fakes/helpers in the file (self-contained `_FakeStub` / `_FakeConnection`, `readyTimeout: const Duration(hours: 1)`). Do not edit the golden-master file.

- [x] **Task 4: Reconcile the stale governing spec note** (independent; documentation only)
  Files: `.ai-factory/notes/17-rootchild-bio-to-root.md`
  Note 17 §Change (line 22) still prescribes *"Keep the `disconnect` path clearing `_sessionConfirmed` and re-arming on reconnect (root id re-learned via note 15 re-open)."* That instruction is falsified by `SessionRegistry.rootIdChanges` being `.distinct()`: the reconnect re-open re-emits the *same* idempotent `root.id`, which is suppressed, so nothing re-arms `_sessionConfirmed` — it literally describes the reconnect bug this milestone fixes. Update that clause to match the implemented behavior: in root-sourced mode the `disconnect` path must **not** clear `_sessionConfirmed` (root liveness, not transport, is the gate); it is cleared only when `rootId` goes null. This keeps the spec tree from re-introducing the disconnect-clear for a future reader. No code impact.
