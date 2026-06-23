# Plan: Meditation timer driven by absolute wall-clock delta

## Context
Make the meditation session timer correct under tick throttling or process suspension by deriving `elapsedSeconds` from a wall-clock delta instead of an incrementing accumulator. The 1 s periodic timer becomes a UI-refresh cadence only.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Clock-delta timer

- [x] **Task 1: Derive elapsedSeconds from wall-clock delta**
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  Add a `DateTime? _startedAt` field alongside the existing `_timer`/`elapsedSeconds`.
  In `start()`: set `_startedAt = DateTime.now()`, set `elapsedSeconds.value = 0`, and keep the existing `Timer.periodic(const Duration(seconds: 1), ...)` — but change its callback to recompute from the clock instead of incrementing: `elapsedSeconds.value = DateTime.now().difference(_startedAt!).inSeconds`. Leave the `state = state.copyWith(status: MeditationSessionStatus.active)` line as is.
  In `stop()`: keep `_timer?.cancel()` / `_timer = null`, additionally clear `_startedAt = null`, and leave the status transition to `idle` unchanged.
  Guards: the 1 s periodic must remain so the UI updates every second; the displayed value comes only from the clock delta (no `++` accumulator). `_startedAt` is re-armed on every `start()` so repeated sessions count correctly. Do not touch the `build()` `ref.onDispose` path — it already cancels the timer and disposes `elapsedSeconds`. Pure client-side change; no server or proto impact.
