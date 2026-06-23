# Plan Review: Meditation timer driven by absolute wall-clock delta

**Plan:** `.ai-factory/plans/75-meditation-timer-driven-by-absolute-wall-clock-delta.md`
**Files Reviewed:** 1 plan + target source (`MeditationSessionViewModel.dart`), screen, state model, tracking channel, spec note 141, ROADMAP
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** OK — change is confined to the presentation package ViewModel; respects the module boundary (domain models / DTOs are untouched, no `lib/` import added).
- **Rules (`RULES.md`):** OK — the three rules concern Module Services, App.dart, and constructor injection. This change touches none of them; the ViewModel already owns its own `_timer` lifecycle via `ref.onDispose`.
- **Roadmap (`ROADMAP.md`):** OK — directly implements milestone line 251 ("Meditation timer driven by absolute wall-clock delta"). Linkage is explicit and the plan matches the milestone's stated approach and guards.

## Verification Against Codebase

- **File path correct:** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart` exists and contains exactly the `start()`/`stop()`/`elapsedSeconds`/`_timer` shape the plan describes.
- **API usage correct:** `DateTime.now().difference(_startedAt!).inSeconds` is valid Dart and yields the intended integer seconds. `Timer.periodic` callback signature and `elapsedSeconds` (a `ValueNotifier<int>`) are used correctly.
- **Display path safe:** The screen (`MeditationSessionScreen.dart:94-95`) drives the timer text via `ValueListenableBuilder` on `elapsedSeconds`, using `ref.read` (no per-second Riverpod rebuild). The change keeps `elapsedSeconds` as the single source, so the UI keeps working unchanged.
- **No duration regression elsewhere:** `MeditationModuleStateChannel` reports session lifecycle from `status` transitions and `DateTime.now()` timestamps (lines 39, 42), **not** from `elapsedSeconds`. So changing how `elapsedSeconds` is derived has zero effect on server-side `startedAt`/`endedAt` — it is purely a UI display value, as the plan claims.
- **Re-arm correct:** `start()` resetting `_startedAt` each call matches the channel's re-arm logic (`MeditationModuleStateChannel.dart:42-47`); repeated Start→Stop→Start cycles count from zero correctly. No pause/resume concept exists in this module (confirmed: no `pause`/`resume` in the package), so the stop→idle→start reset is the complete state space.
- **Dispose path:** `build()`'s `ref.onDispose` already cancels `_timer` and disposes `elapsedSeconds`; the plan correctly leaves it alone. `_startedAt` needs no explicit dispose handling (plain nullable field, GC'd with the notifier).

## Critical Issues

None.

## Non-Blocking Observations (optional, no plan change required)

1. **Wall-clock vs. monotonic clock (intentional, worth noting).** Using `DateTime.now()` rather than a `Stopwatch` is the *correct* choice for the stated goal: a `Stopwatch`/monotonic source does not reliably accrue time while a process is suspended on iOS, so it would not survive lock/suspend — exactly the failure this milestone fixes. The trade-off is sensitivity to system-clock adjustments (manual change / NTP step) mid-session: a backward step could make `difference(...).inSeconds` momentarily decrease or go negative, which `_formatDuration` would render oddly (negative `~/` and `%`). This is a rare edge case, already shared by the client-timestamp approach in note 137, and not worth guarding here — just flagging the assumption.

2. **Sub-second tick jitter.** `inSeconds` truncates, and the 1 s periodic fires on its own phase relative to `_startedAt`. The displayed value may occasionally appear to dwell or jump by the truncation boundary, but it will always equal true elapsed whole-seconds at read time — acceptable and arguably more correct than the old accumulator.

3. **Double-`start()` timer leak (pre-existing, not introduced).** If `start()` were ever called while already active, the prior `Timer.periodic` would leak (no `_timer?.cancel()` at the top of `start()`). The UI gates `start()` behind the `idle` state (`isActive ? stop() : start()`), so this is currently unreachable; the plan does not make it worse. No action needed.

## Positive Notes

- Plan is faithful to its spec (note 141) — same field, same callback formula, same guards.
- Correctly identifies the change as pure client-side with no proto/server/migration impact, and that assertion is verified against the tracking channel.
- Scope is tightly bounded to one method body in one file; explicitly preserves the dispose path and the 1 s UI cadence.
- "Logging: minimal" with no added log is appropriate for a one-line behavioral change.

PLAN_REVIEW_PASS
