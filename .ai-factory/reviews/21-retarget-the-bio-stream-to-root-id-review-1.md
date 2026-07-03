# Code Review: Retarget the bio stream to `root.id`

**Plan:** `.ai-factory/plans/21-retarget-the-bio-stream-to-root-id.md`
**Files changed (code):** `lib/Biometrics/BiometricStreamClient.dart`, `lib/Core/App.dart`, `test/Biometrics/biometric_stream_id_routing_test.dart` (+ doc-only `.ai-factory/notes/17-rootchild-bio-to-root.md`)
**Risk level:** 🟢 Low — small, faithful diff; no blocking issues.

## What I did
- Read `git diff HEAD` / `git status` in full.
- Read the modified `BiometricStreamClient.dart` in full (not just the hunk) and the surrounding gate / sink / encode paths.
- Verified the wiring point in `App.dart:234` against `rootStateChannel` (built at `:225`, exposes `rootIdChanges`).
- Traced every scenario the plan and prior plan-reviews raised.
- **Ran the tests** (`biometric_stream_id_routing_test.dart`, `biometric_stream_client_test.dart` golden master, `biometric_batcher_test.dart`): **42/42 pass**, including the new reconnect regression test and the never-edited golden master.

## Correctness trace

- **Bio → root.id, phases untouched.** `_onRootIdChanged` now drives `_currentSessionId`/`_sessionConfirmed`; the encode path (`:246-253`) tags `BioSample.sessionId` with it. The phase/instruction path (`BreathModuleStateChannel` → `ModuleInstructionStream`) is not touched, so phase samples keep the child id. The two sources stay decoupled as required.
- **Dual-mode switch is sound.** `_rootSourced = rootIdChanges != null` is set in the initializer list (valid Dart; `rootIdChanges` is in scope). Production always passes the stream → root-sourced; the golden master constructs without it → legacy lifecycle path intact (`_onLifecycleEvent` early-returns only when `_rootSourced`). Confirmed by the golden master staying green.
- **Reconnect gap closed.** `disconnected` now guards the `_sessionConfirmed = false` clear with `if (!_rootSourced)`, while `_teardownSink()` stays unconditional. Traced: send under root-1 → `disconnected` tears down the sink but retains id + confirmation → clock +3 s clears the 2 s reopen cooldown → `connected` reopens → post-reconnect `sendBatch` passes the gate and drains under root-1. The new test reproduces exactly this and fails on the pre-fix behavior (id retained but `_sessionConfirmed` stuck false → gate drops every sample → empty batch).
- **Root-gone path.** `_onRootIdChanged(null)` clears id, drops confirmation, re-arms the cooldown, and empties the replay ring without tearing down the sink — matching routing test 3 (inject `ready` on the still-open connection drains nothing).
- **Cold-start ordering.** Production `rootIdChanges` is a seeded `.distinct()` stream: the initial `null` fires `_onRootIdChanged(null)` (harmless no-op on empty state); `connected` may open the sink before the root id is known, but the send gate holds samples until the root arrives — pre-existing behavior, unchanged.
- **No other consumers break.** Only `App.dart:234` constructs the client; `biometric_batcher_test.dart` uses a fake `implements BiometricStreamClient`, unaffected by the new optional parameter.
- **Docstring / spec reconciled.** Class comment (`:14-24`) and note 17 §Change updated to describe root-sourced behavior — no longer prescribing the disconnect-clear bug.

## Non-blocking observations (no action required)

- **Sends during the disconnect window** now pass the gate (id + confirmation survive), so a `sendBatch` while transport is down may attempt `streamData` against a dead channel. This is self-healing: a failed open lands in `catch`/`onError` → `_teardownSink`, samples fall to the replay ring (bounded, drop-oldest), and the next `connected` drains them. Intended consequence of "root liveness, not transport, is the gate." Already noted in plan-review 3; not a defect.
- **`_onRootIdChanged` non-null path does not clear the replay ring.** A direct root-A → root-B transition (no intervening `null`) would drain A's buffered samples under B's id. This cannot occur under the system invariant (root id is idempotent per user; a new root only appears after logout/login, which routes through `clear()` → a real `null` emission first). Correct given the contract; flagging only for awareness.

## Verdict

The change is minimal, matches the reviewed plan, correctly closes the reconnect regression identified in plan-review 1, and all affected tests (including the golden master and the new reconnect test) pass. No correctness, security, migration, or race-condition issues found.

REVIEW_PASS
