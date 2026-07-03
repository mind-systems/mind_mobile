# Plan: Pending-start state lift (behaviour-preserving)

## Context
Turn `ModuleStateChannel`'s implicit, scattered pending-start state (`_pendingStarts` vs `_deferredStarts` membership + nullable `timer` + `_settlingActive`, with the `isConnected`+3-attempt-budget guards copy-pasted per resolution site) into an explicit state model behind **one guarded chokepoint** that owns the two preconditions — so a new resolution site (note-29 per-child RESUMED) cannot skip a guard, the root cause of task 26's three-round review chain.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Constraints (from spec note `.ai-factory/notes/28-rootchild-pending-start-state-lift.md`)
- **Behaviour-preserving.** All four suites in `test/Core/Grpc/` must stay **green and unmodified**: `start_race_contract_test.dart`, `start_race_giveup_contract_test.dart` (note-27 golden master), `module_state_channel_test.dart`, and the shared `Support/reconnect_concurrency_harness.dart`. No new test file, no assertion weakened, no invariant change (INV-8/9/10/11/12, SC-1/2/3/7 stay green).
- **The chokepoint is load-bearing; the enum is secondary.** Do not cargo-cult a full `_transition`-style hub mirroring `ConnectionLifecycle`. The failure mode being closed is *a caller skipping a precondition* — the single guarded chokepoint prevents it. An explicit representation is added only where it clarifies transitions.
- **Command-level only.** This lift stays out of the note-25 `ConnectionLifecycle` FSM (`_lifecycle`/`_transition`) — it is orthogonal, touching only the command-level pending-start state.
- **Do NOT fold in note 29.** The per-child RESUMED consumption is a separate task that *lands on* this chokepoint; here we only make the seam ready (the chokepoint + the confirmed-clear point), never implement note 29.
- **Single-precondition ordering.** The chokepoint evaluates **budget first, then `isConnected`**, mirroring today's `_onConfirmTimeout`. This intentionally unifies the two sites' historically-inconsistent ordering (`_resolveSettling`'s carried path checked `isConnected` before budget); the divergence is confined to an untested edge (budget-spent *and* transport-down at settling-resolve) that no assertion pins — verified by the four suites staying green.

## Design (chosen chokepoint)
A single method owns every precondition-bearing send decision and returns an outcome; each trigger applies only its own **hold strategy** (never a precondition re-check):

```dart
enum _StartOutcome { sent, gaveUp, held }

/// The ONE place the retry-budget and transport-liveness preconditions are
/// evaluated for a pending-start send. Every resolution trigger routes here.
_StartOutcome _resolveStart(_PendingStart p) {
  if (p.attempts >= 3) { _giveUp(p.type); return _StartOutcome.gaveUp; }
  if (!isConnected) return _StartOutcome.held;
  _beginStart(p);              // register (idempotent for already-registered) + send
  return _StartOutcome.sent;
}
```

`_beginStart` (`_pendingStarts[type]?.timer?.cancel(); _pendingStarts[type] = p; _sendStart(p);`) already works for both an already-registered carried/armed pending (self-assign, no-op timer cancel) and a not-yet-registered released deferred start — so the send branch is uniform. Hold strategies stay in the callers but read only the abstract `held` outcome:
- `_onConfirmTimeout` → re-arm the 5s wait timer.
- `_resolveSettling` carried → nothing (leave dormant; next reconnect window re-resolves).
- `_resolveSettling` deferred-release → re-defer into `_deferredStarts`.

## Tasks

### Phase 1: The guarded chokepoint

- [x] **Task 1: Add `_StartOutcome` + the `_resolveStart` chokepoint**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Add a private `enum _StartOutcome { sent, gaveUp, held }` and the `_resolveStart(_PendingStart p)` method exactly as in the Design section: budget check first (`attempts >= 3` → `_giveUp(p.type)`, return `gaveUp`), then `isConnected` (false → return `held`, no attempt consumed), else `_beginStart(p)` (register + send) and return `sent`. Keep `_beginStart`, `_sendStart`, and `_giveUp` as-is (the chokepoint composes them; it does not duplicate their bodies). Add a doc comment stating this is the sole owner of the budget + `isConnected` preconditions and that all resolution triggers route through it. Do not wire any caller yet.

### Phase 2: Route every resolution trigger through the chokepoint

- [x] **Task 2: Route `_onConfirmTimeout` through `_resolveStart`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Replace the inline budget + `isConnected` branches (`:505-516`) with: fetch `p = _pendingStarts[type]`, `if (p == null) return;`, then `if (_resolveStart(p) == _StartOutcome.held) { p.timer = Timer(const Duration(seconds: 5), () => _onConfirmTimeout(type)); }`. The re-arm-on-held is the only caller-side logic left — it is a hold strategy, not a precondition check. Net behaviour identical: confirmed→no-op (p null), budget-spent→give up, connected→resend, down→re-arm without consuming an attempt.

- [x] **Task 3: Route `_resolveSettling` carried + deferred paths through `_resolveStart`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_resolveSettling` (`:551-572`), remove the per-path `isConnected` and budget checks and route both through the chokepoint:
  - Deferred-release loop: keep the adopt short-circuit (`if (_registry.childOfType(p.type) != null) continue;` — an already-satisfied guard, not a precondition), then `if (_resolveStart(p) == _StartOutcome.held) _deferredStarts[p.type] = p;` (re-defer is the hold strategy; on `sent`, `_resolveStart→_beginStart` registers it in `_pendingStarts`).
  - Carried loop: keep `final p = _pendingStarts[type]; if (p == null) continue;`, then just `_resolveStart(p);` (a `held` outcome leaves it dormant in `_pendingStarts`, matching today's `continue`; `gaveUp`/`sent` handled inside). Keep the `carriedTypes` snapshot taken before the deferred loop so a freshly-released deferred start is not re-sent twice in one pass.
  Confirm the note-27 carried-budget golden master (`3-attempt-spent carried pending gives up ... no 4th send`) stays green — it exercises this exact path while connected.

### Phase 3: Explicit state model + confirmed seam

- [x] **Task 4: Make the pending-start states explicit and pin the confirmed-clear seam** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Two behaviour-neutral clarifications:
  1. Document the explicit state model on the `_pendingStarts` / `_deferredStarts` declarations (and/or `_PendingStart`): enumerate the five states — **armed** (in `_pendingStarts` with a live confirm timer), **carried** (in `_pendingStarts`, timer cancelled during a reconnect settling window), **deferred** (in `_deferredStarts`, awaiting settling resolution), **confirmed** (terminal — removed by `_clearPendingStart`), **given-up** (terminal — removed by `_giveUp`) — and which representation encodes each. (An explicit `enum PendingStartPhase` field on `_PendingStart` is optional and secondary — add it only if it stays fully redundant with map membership and introduces zero behaviour change; prefer documentation over a redundant field.)
  2. Keep `_clearPendingStart` as the single **confirmed** resolution point (already the only clear-on-confirmation site, called from the RESUMED and ACTIVE branches) and add a one-line comment that this is the seam note-29's per-child RESUMED consumption will call — so the confirmed transition, like the send decision, has exactly one owner. No logic change.

### Phase 4: Verify behaviour preservation

- [x] **Task 5: Run the Grpc suite and confirm green + unmodified** (depends on Tasks 2, 3, 4)
  Files: — (no edits; verification)
  Run `/usr/local/bin/flutter test test/Core/Grpc/`. All of `start_race_contract_test.dart`, `start_race_giveup_contract_test.dart`, `module_state_channel_test.dart`, and `Support/reconnect_concurrency_harness.dart` must be **green and byte-unchanged** (verify with `git diff --stat test/`). If any test file needed a change to pass, the refactor is not behaviour-preserving — fix the production code, never the test. Confirm no caller of a pending-start resolution re-checks `isConnected` or the 3-attempt budget outside `_resolveStart`.

## Commit Plan
- **Commit 1** (after tasks 1-5): "Lift pending-start resolution behind one guarded chokepoint" — one cohesive behaviour-preserving refactor of `ModuleStateChannel`; commit only once the full `test/Core/Grpc/` suite is green with the test files unmodified.
