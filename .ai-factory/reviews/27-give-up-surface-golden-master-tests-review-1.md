# Code Review: Give-up-surface golden-master tests (round 1)

## Scope
`git diff HEAD` / `git status` show four new staged files. Only one is code:

- `test/Core/Grpc/start_race_giveup_contract_test.dart` (new, 204 lines) — the deliverable.
- `.ai-factory/plans/27-*.md`, `.ai-factory/plans/27-*.json`, `.ai-factory/plan-reviews/27-*.md` — planning artifacts, not reviewed for runtime behaviour.

No production code was changed (as required by the milestone). The shared harness `Support/reconnect_concurrency_harness.dart` was not modified.

## Verification
- `flutter test test/Core/Grpc/` → **All tests passed** (136 tests), including the pre-existing `start_race_contract_test.dart` suite — no existing assertion regressed or was weakened.
- `flutter test test/Core/Grpc/start_race_giveup_contract_test.dart --reporter expanded` → all **4** new tests run (none skipped) and pass. The golden-master contract ("green on the current tree, no production change") holds.

## Traced correctness (each test vs. production code)

**Surface 1 — type-scoped adapter reset (2 tests).** Correct.
- Observable seam is sound: `BreathModuleStateChannel` sets `_moduleSessionId` unconditionally on every `channel.state` emission and `MeditationModuleStateChannel` sets it only when non-null; in both tests no `_state` emission occurs during the sibling's give-up (`_giveUp` touches only `_events`), so the confirmed session's `moduleSessionId` is stable and the assertion is meaningful.
- The distinguishing power is real: if the `event.type == ...` filter were dropped from an adapter, the sibling `SessionStartFailed` would drive `reset()`/`_reset()` → `moduleSessionId == null`, failing the assertion. The test would catch the regression.
- Give-up trigger is correctly dosed: initial send = attempt 1, two 5 s confirm-timeouts (while `isConnected`, which holds — sub is non-null after the first connect) → attempt 3, third timeout → `_giveUp`. Three `elapse(5 s)` reaches give-up exactly.

**Surface 2 — carried-path budget (1 test).** Correct.
- After attempts 1–3 (t=0/5/10 s) the pending sits at `attempts==3` with a timer armed for t=15 s. The test disconnects at t=10 s *without* a third `elapse`, so `_onConfirmTimeout`'s give-up never fires; the reconnect-open loop cancels the carried timer; the 3 s settling window closes → `_resolveSettling` sees `attempts >= 3` → `_giveUp`, never a 4th `_sendStart`. Total wire `activityStart`s across all calls = 3 (`<= 3`), exactly one `SessionStartFailed(breath)`. This is precisely the INV-12 overshoot the test claims to pin.
- Reconnect classification verified: after disconnect `_lifecycle` is `reconnecting`, so `isReconnectOpen` is true → settling window armed and carried timers cancelled. `isConnected` is true at window-close (sub reopened), so `_giveUp` runs rather than being deferred.

**Surface 3 — emission + snackbar wire (1 test).** Correct.
- Reproduces the exact `App.dart:323` transform `channel.events.where((e) => e is SessionStartFailed).map((_) {})` and asserts it emits once, plus the typed `SessionStartFailed(breath)`. `_events` is a broadcast `PublishSubject`, so both the `_collectFailures` listener and the transform listener receive the event. Asserts close the gap the note calls out (INV-12 only bounded wire count, never the give-up event or the snackbar-feeding stream).

## Non-blocking observations (no action required)
- The `channel.events` listeners in `_collectFailures` and the surface-3 transform are never explicitly cancelled. Harmless: each test builds a fresh `wireConcurrent()`/channel, and `fakeAsync` does not fail on outstanding broadcast subscriptions. Consistent with the existing suite's style.
- The header comment cites commit `93f3e92` as the baseline while current `HEAD` is `858714d`. The give-up surface is unchanged between the two and the tests are green now, so the claim holds in substance; purely cosmetic.

## Conclusion
Additive, self-contained golden-master coverage that faithfully pins all three silently-failing give-up surfaces, is green on the current tree with no production change, and weakens no existing assertion. Every task's assertion was traced to the corresponding production path and confirmed by running the suite. No correctness, security, or runtime-breakage findings.

REVIEW_PASS
