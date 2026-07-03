# Code Review — Reconnect / eviction / start-race concurrency contract (invariants + red scenarios, no production code)

**Risk level:** 🟢 Low — test-only milestone; no `lib/`, proto, or generated code touched.

## Scope
Changed files (new, all under `test/`):
- `test/Core/Grpc/Support/reconnect_concurrency_harness.dart` (390 LOC) — invariant catalogue + self-contained fakes + `wireConcurrent` real-channel/real-adapter fixture.
- `test/Core/Grpc/reconnect_eviction_contract_test.dart` (320 LOC) — eviction/close-classification + reconcile red scenarios (note 20 half).
- `test/Core/Grpc/start_race_contract_test.dart` (311 LOC) — start-race red scenarios (note 19 half).

Plus planning artefacts (`.ai-factory/plans`, `.ai-factory/plan-reviews`, `.json`). No production code, no `.proto` edits, no `build_runner`/`gen_proto.sh` — the milestone's "no production code (m37)" guard is honoured.

## Verification performed
1. **Compilation.** Both test files compile and run — the harness resolves against real symbols. Verified the non-production-used proto symbols the tests construct/read against `lib/Core/Grpc/generated/module_state.pb.dart`:
   - `StateErrorEvent({code, message, timestamp})` ctor (`:457`), `StateResponse({sessionState, sessionError})` (`:693`), `StateEvent({moduleSessionId, status, isPaused, activityType})`, `StateRequest_Command { activityStart, … }`, `whichCommand()` (`:621`), `activityStart` getter (`:631`) — all present.
   - `BreathSessionState` ctor required params (`loadState, phase, exerciseIndex, remainingTicks, currentIntervalMs`) match `runningBreathState()`; `currentPhaseTotalDuration`/`lifecycle` are valid optionals (`packages/breath_module/.../BreathSessionState.dart:59-77`).
   - `MeditationSessionState(status:, poseId:)` matches the existing meditation test usage.
2. **Empirical RED/GREEN labelling** — ran `flutter test` over both files (JSON reporter). Every label matches its actual result:
   - **10 `RED now` tests FAIL as intended:** INV-1/SC-4, INV-2/SC-6, INV-4, INV-5/SC-3, INV-6, INV-8/INV-9/SC-2, INV-10 (cross-type), SC-1/INV-8, INV-11/SC-3, INV-11 (symmetric).
   - **6 `GREEN-now guard` tests PASS:** INV-1/SC-5 (bare close), INV-1 (onError), INV-7 (is_paused), INV-8 (post-confirm no-retry), INV-12 (attempt ceiling), INV-10/SC-7 (same-type adopt).
   - **1 SKIP:** INV-3 (`takeOverHere()`), correctly guarded behind `skip:` with a dynamic dispatch so the file compiles ahead of note 20's seam.
   This directly discharges plan-review-1's Critical Issue 1 (no "RED" label sits on a test that passes today) and Critical Issue 2 (SC-1 asserts purely on the wire — `_starts(...).length == 2` — never on a private pending field).
3. **Behavioural trace against `ModuleStateChannel`** — confirmed each RED failure is caused by the exact production gap the note-19/20 impl will close (unconditional `scheduleReconnect` on `onDone` `:126-131`; unconditional reopen on `connected` `:75-76`; registry never cleared on close/reopen `:136-141`; root-level ABANDONED removes only the root's own entry via `_handleRootFrame`; shared `_isPendingStart`/single-state guard at `:237`; no retry/settling-window machinery). The `globalResetFrame()` UNSPECIFIED path correctly reaches the `_registry.clear()` branch (`:184-190`) as its doc comment claims.

## Findings
No correctness, security, or runtime-safety defects. Specifically checked and cleared:
- **Null-sink ordering** — `connectAndFlush` pushes `connected` + flushes before any adapter is driven, so `channel.start` is never swallowed by the null-sink guard; the "start reached the wire" assertions fire. The ordering pin is documented on `wireConcurrent`.
- **`fakeAsync` hygiene** — no `Future.delayed`; every `responseCtrl.add`/state emission is followed by `flushMicrotasks()`. Current code creates no timers on these paths, so no pending-timer leakage; `async.elapse` windows are already in place for the note-19/20 timers.
- **Broadcast subscriptions** — the channel subscribes to `connectionState`/`authStream` in its constructor (before any push), so no missed broadcast events.
- **`.distinct()` on `rootIdChanges`** does not affect the `rootId` getter (reads `BehaviorSubject.value`), so INV-4's stale-root assertion is exercised correctly.

## Non-blocking observations (no action required)
- **Expected suite-wide red until the impls land.** These 10 failing tests are the intended TDD-first deliverable; a full `flutter test` run will report red between this commit and notes 19/20 — matching the established precedent (`biometric_stream_id_routing_test.dart`, roadmap tasks 67→68). Not a defect.
- **Fixture teardown** disposes `channel` but leaves adapters/stream-controllers unclosed. Harmless (fresh fixture per test, no cross-test state, controllers GC'd) and consistent with existing channel/adapter tests; noted only for completeness.
- INV-6 builds its ABANDONED frame inline rather than via a harness helper — cosmetic.

The milestone delivers exactly what the plan and note 24 specify: a durable written invariant catalogue plus an executable, empirically-verified RED/GREEN contract driven through real stateful doubles (m36), with the single un-expressible invariant (`takeOverHere()`) correctly parked as a documented skip.

REVIEW_PASS
