# Activity-boundary characterization golden master (current behavior) (T2)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- Existing coverage is real but representation-coupled: `breath_session_state_machine_test.dart` pins pause/resume/complete + progression at the SM; `breath_module_state_channel_test.dart` exhaustively pins the **server** translation (`start/pause/unpause/end/stop`) feeding `BreathSessionState` with `status:`. Both assert on `BreathSessionStatus` — the very enum the refactor splits. They are kept as the cheaper inner net.
- **Blind spot — the `_hasStarted` discriminator is untested.** `resume()` emits `ResetReason.start` only on the FIRST activation (`BreathSessionStateMachine.dart:189`, `_hasStarted = true` `:205`); later resumes emit `null`. This is the **only** in-engine discriminator between "not started" and "manually paused" and the surgery must preserve it.
- Other untested invariants the surgery could silently break: restart rebuilds to a fresh initial `pause` with zeroed counters (`BreathSessionViewModel.restartEngine:282` → `_setupEngine:139`); ticks are ignored in `pause` **and** `complete` (`_onTick:237`).

## Details

Using the [[165-breath-headless-activity-harness]], add an **activity-boundary** suite that feeds `(DTO, ticks, resume/pause/complete/restart)` and asserts the emitted `BreathSessionState` sequence (`status`, `phase`, `exerciseIndex`, `resetReason`, `remainingTicks`) as an executable golden master — internals-agnostic. Cases:

- **first resume → `resetReason == start`; pause; second resume → `resetReason == null`** — the `_hasStarted` contract expressed as input→output ("resume from not-started" vs "resume from paused" differ observably).
- **restart after complete → `status == pause`, `exerciseIndex == 0`, counters reset, fresh initial state.**
- **tick while `pause` (not started) → no progression; tick while `complete` → no progression.**
- the server-translation golden master (`breath_module_state_channel_test.dart`) is left as-is and is part of the contract the surgery preserves.

## Guards

- **Green NOW** — characterizes current behavior before any change.
- Assertions are behavioral (input→output). In T2 they still assert on the **current** schema (`status`); [[167-breath-derive-lifecycle-islive]] adds the new fields and [[172-breath-retire-derived-status]] migrates these assertions. Do not pre-emptively assert on `lifecycle` here.
- No prod change. Do not rewrite the existing SM/channel suites in this task.

## Verify

- Full suite green on the **pre-refactor** code; committed as the contract the surgery ([[171-breath-extract-owned-lifecycle-fsm]]) must preserve with no assertion edits.
