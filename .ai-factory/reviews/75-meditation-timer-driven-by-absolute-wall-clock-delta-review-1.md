# Code Review: Meditation timer driven by absolute wall-clock delta

**Plan:** `.ai-factory/plans/75-meditation-timer-driven-by-absolute-wall-clock-delta.md`
**Files changed (code):** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
**Risk Level:** 🟢 Low

## Summary

The change converts `elapsedSeconds` from an incrementing accumulator into a value
recomputed from a wall-clock delta on each 1 s tick. The diff matches the plan and
spec note 141 precisely:

- `DateTime? _startedAt` field added.
- `start()` sets `_startedAt = DateTime.now()`, resets `elapsedSeconds.value = 0`,
  keeps the 1 s `Timer.periodic`, and its callback now computes
  `elapsedSeconds.value = DateTime.now().difference(_startedAt!).inSeconds`.
- `stop()` cancels/nulls the timer, additionally clears `_startedAt = null`, and
  preserves the `idle` transition.
- The `build()` `ref.onDispose` path is untouched (still cancels `_timer`, disposes
  `elapsedSeconds`).

## Correctness verification

- **Null-safety of `_startedAt!`:** The timer is only created inside `start()` *after*
  `_startedAt` is assigned a non-null value, and is cancelled in `stop()` and in
  `ref.onDispose` before `_startedAt` is cleared. There is no window where the timer
  callback can fire with `_startedAt == null`, so the `!` assertion is safe.
- **Re-arm on repeated sessions:** Each `start()` reassigns `_startedAt` and zeroes
  the counter, so Start→Stop→Start cycles count from zero correctly. No pause/resume
  concept exists in this module.
- **Consumer unaffected:** `MeditationSessionScreen.dart:95` binds the timer text via
  `ValueListenableBuilder` on the same `elapsedSeconds` notifier through `ref.read`
  (no per-second Riverpod rebuild). The notifier identity and type (`ValueNotifier<int>`)
  are unchanged, so the UI keeps working. `_formatDuration` still receives an `int`.
- **No server/proto impact:** `elapsedSeconds` is a display-only value; session
  lifecycle reporting is driven by `status` transitions, not this counter. Pure
  client-side change — no migration, DTO, or proto concern.
- **Suspension behavior is the intended fix:** On resume after throttling/suspension
  the next tick snaps `elapsedSeconds` to true wall-clock seconds (may jump forward —
  correct), instead of resuming a frozen lower count.

## Non-blocking observations

1. **Wall-clock vs monotonic (intentional).** `DateTime.now()` is the correct source
   for surviving suspend/lock, but it is sensitive to a backward system-clock step
   (manual change / NTP correction) mid-session, which could momentarily yield a
   decreasing or negative `inSeconds` and render oddly in `_formatDuration`. This is a
   rare edge case, consistent with the existing client-timestamp approach, and not
   worth guarding here. No action required.
2. **Sub-second truncation jitter.** `inSeconds` truncates and the 1 s tick has its own
   phase relative to `_startedAt`; the display always equals true elapsed whole-seconds
   at read time. Acceptable and arguably more accurate than the old accumulator.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
