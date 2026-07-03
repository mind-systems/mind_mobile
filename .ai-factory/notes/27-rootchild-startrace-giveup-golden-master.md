# Root/child — start-race give-up-surface golden-master tests

**Date:** 2026-07-04
**Source:** conversation context (milestone-rescue of task 26); code review 3 of task 26

## Key Findings

- Task 26 (start-race hardening) shipped correct and green (`start_race_contract_test.dart` covers INV-8/9/10/11/12, SC-1/2/3/7), but code review 3 flagged that the **give-up half** of the feature shipped with **zero test coverage** on a `Testing: yes` milestone — `grep -rn SessionStartFailed test/` returns nothing, and neither adapter suite was touched.
- Three give-up surfaces fail **silently** (wrong behaviour, no crash — `test-philosophy` targets); if any regresses in a later edit nothing fails loudly:
  1. **Type-scoped adapter reset** — a `SessionStartFailed(type)` give-up must reset only that type's adapter. If the `event.type == ActivityType.breath` filter is dropped, a meditation give-up silently clears a **live** breath session's `_started` / `_moduleSessionId` / stopwatch mid-practice.
  2. **Carried-path budget enforcement** — a pending start whose 3-attempt budget is spent must give up via the shared `_giveUp` helper, not emit a **4th** wire send when a settling window re-resolves it (this is exactly the INV-12 overshoot review 2 caught and that was fixed reactively — no regression test pins it).
  3. **`SessionStartFailed` emission** — the event must fire after the 3rd unconfirmed attempt and reach the `App.dart` snackbar wire. INV-12's test only bounds the wire count `<= 3`; it never asserts the give-up event or the snackbar.
- **This is the golden master.** These tests must go **green on the current committed code** (commit `93f3e92`) so they lock behaviour *before* the state lift (note 28) refactors the internals. Same pattern as the note-25 ConnectionLifecycle behaviour-preserving lift: tests first, green now, still green after the lift.

## Details

### Current state (exact — commit `93f3e92`)
- Type-scoped reset: `BreathModuleStateChannel.dart:53-58`, `MeditationModuleStateChannel.dart:35-40,50-56`.
- Shared give-up: `_giveUp(type)` `ModuleStateChannel.dart:521-524`, called from `_onConfirmTimeout` `:506` and the `_resolveSettling` carried loop `:566-569`.
- Confirm-clear: `_clearPendingStart` on ACTIVE/RESUMED of the exact `activity_type`.
- Snackbar wire: `SessionStartFailed` → `GlobalListeners` → `App.dart:323` (`sessionStartFailedStream`); ARB key `sessionStartFailed` present in `app_en.arb` / `app_ru.arb`.
- Test harness: `wireConcurrent` in `start_race_contract_test.dart` already stands up **both real adapters + the real registry** — the type-scoped-reset assertion is cheap on it.

### Change (tests only — no production code)
1. **Type-scoped reset** — drive one type (meditation) to give-up via 3 unconfirmed timeouts; assert the **other** adapter (breath) still reports its live session (`_started == true`, session id intact). Symmetric case for the reverse.
2. **Carried-path budget** — spend a breath start's budget (3 attempts across confirm-timeouts while connected), drop the transport across a reconnect so the carried pending survives into a settling window, elapse the window; assert total wire `start`s `<= 3` **and** a `SessionStartFailed` is emitted — no 4th send.
3. **Give-up emission** — after the 3rd unconfirmed attempt assert `channel.events` emits `SessionStartFailed(type)` with the correct type, and the `App.dart` snackbar path is reached.

### Guards
- Tests render into `start_race_contract_test.dart` (or a sibling in `test/Core/Grpc/`), **not** `ROADMAP_TESTS.md` — they belong to the impl chain (golden master → lift).
- Do **not** weaken any existing contract-test assertion; this is additive coverage.
- Must be green on `93f3e92` before note 28 starts.

### Verify
- `flutter test test/Core/Grpc/` green including the three new assertions, on the current tree, with no production change.
