# Code Review: Pending-start state lift (behaviour-preserving) — Review 1

## Scope
Single production file changed: `lib/Core/Grpc/ModuleStateChannel.dart` (+114/−33). The rest of the diff is planning artifacts (`.ai-factory/plans/*`, `.ai-factory/plan-reviews/*`). No test files touched (`git diff --stat test/` empty), no proto/migration/schema changes.

## Verification performed
- Read `ModuleStateChannel.dart` in full and compared each routed site against its pre-refactor form.
- Ran `flutter test test/Core/Grpc/` → **136 tests passed**, including the two behaviour-preserving anchors (`start_race_contract_test.dart`, `start_race_giveup_contract_test.dart`), `module_state_channel_test.dart`, and `reconnect_eviction_contract_test.dart`.
- Confirmed the four required suites are byte-unchanged.

## Behavioural-equivalence analysis

**`_onConfirmTimeout` (Task 2).** Old code branched budget → `isConnected` → send/re-arm inline. New code delegates the send decision to `_resolveStart` and keeps only the re-arm as its hold strategy. Equivalent on every branch:
- `attempts >= 3` → `_giveUp` (both).
- connected → old `_sendStart(p)`; new `_beginStart(p)`. Since `p == _pendingStarts[type]`, `_beginStart`'s `_pendingStarts[p.type]?.timer?.cancel()` + `_pendingStarts[p.type] = p` are a self-cancel (timer already fired) + self-assign, then `_sendStart(p)` — observably identical.
- down → re-arm 5s timer, no attempt consumed (both).

**`_resolveSettling` deferred-release (Task 3).** Deferred pendings are only ever created with `attempts == 0` (in `start()` or re-deferred while held), so `_resolveStart`'s budget branch is unreachable for them. Remaining branches: down → re-defer (old and new); connected → `_beginStart` (old and new). Equivalent. `carriedTypes` is still snapshotted before the deferred loop, so a just-released deferred start is not re-sent by the carried loop.

**`_resolveSettling` carried (Task 3).** Connected + budget-ok → old `_sendStart(p)`, new `_beginStart(p)` (self-cancel/self-assign, equivalent; carried timers were nulled at window open). Budget-spent + connected → `_giveUp` (both) — this is the path the note-27 carried-budget golden master pins, and it stays green.

**Same-type carried + deferred cannot coexist.** `start()`'s `_pendingStarts.containsKey(type)` guard (line 429) runs before the settling-defer branch, so a type already carried in `_pendingStarts` never spawns a `_deferredStarts` entry. This is why the deferred loop's `_beginStart` can never clobber a live same-type carried pending — the invariant holds unchanged.

**No concurrent-modification hazards.** The deferred loop iterates a copy (`Map.from(_deferredStarts)`); the carried loop iterates a `List` snapshot (`carriedTypes`). `_giveUp`/`_beginStart` mutating the underlying maps during iteration is safe.

## Observations (non-blocking)

### O1 — Intentional ordering unification shifts one untested edge (accepted by spec)
`ModuleStateChannel.dart:510-518` — `_resolveStart` checks budget **before** `isConnected`. The old carried path checked `isConnected` first (`if (p == null || !isConnected) continue;`), so it never gave up while disconnected. In the exact edge — a carried pending with `attempts >= 3` resolved by a settling window while the transport is down (reachable because `_reconcileTimer` is not cancelled on a mid-window stream drop) — new code emits `SessionStartFailed` + removes the pending, where old code kept it dormant and gave up one reconnect later. Consequence: in a rare race (budget fully spent, disconnect inside the settling window, then a late server RESUMED after reconnect) the user could see a spurious "start failed" surface immediately followed by the session appearing.

This is explicitly called out and accepted in the plan's **Single-precondition ordering** constraint: no single ordering can preserve both `_onConfirmTimeout`'s and `_resolveSettling`'s historically-inconsistent edge behaviour simultaneously (that inconsistency is the root cause the lift closes), and the divergence is confined to a path no assertion pins. The four required suites are green. **No change required** — flagged only so the tradeoff is on record; if the team wants to fully avoid the spurious-snackbar race, preserving `isConnected`-first ordering in the carried path (at the cost of shifting the equivalent edge onto `_onConfirmTimeout`) is the only alternative, and neither is strictly better.

## Correctness / security / runtime
No correctness bugs, no null-safety gaps, no security concerns, no race conditions introduced beyond the accepted edge above. The refactor composes existing helpers (`_beginStart`/`_sendStart`/`_giveUp`) rather than duplicating them, and centralises the two preconditions in `_resolveStart` as intended — a new resolution site (note 29) plugging into `_resolveStart` inherits both guards, which is the milestone's goal.

REVIEW_PASS
