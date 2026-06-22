# Meditation timer driven by absolute wall-clock delta

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- `MeditationSessionViewModel` counts elapsed time with an **incrementing** `Timer.periodic(1s, () => elapsedSeconds.value++)`. Any tick throttling or process suspension (e.g. a backgrounded/locked device) under-counts elapsed seconds — the timer freezes and resumes from where it stopped.
- Deriving `elapsedSeconds` from a **wall-clock delta** makes the displayed duration correct regardless of throttling/suspension. Independently valuable even before the background-keep-alive work lands.

## Details

### Current state
`packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`:
```dart
final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
Timer? _timer;

void start() {
  elapsedSeconds.value = 0;
  _timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++);
  state = state.copyWith(status: MeditationSessionStatus.active);
}

void stop() {
  _timer?.cancel();
  _timer = null;
  state = state.copyWith(status: MeditationSessionStatus.idle);
}
```
Meditation plays no audio and has no other time source.

### Change
- Add `DateTime? _startedAt`. In `start()` set `_startedAt = DateTime.now()`, `elapsedSeconds.value = 0`, and keep the 1 s `Timer.periodic` **only as a UI refresh cadence** — its callback recomputes from the clock: `elapsedSeconds.value = DateTime.now().difference(_startedAt!).inSeconds`.
- `stop()` cancels the timer and clears `_startedAt`; re-arm on the next `start()`.
- On resume after any throttling/suspension the very next tick snaps `elapsedSeconds` to the true wall-clock value (it may jump forward — correct).

### Guards
- Keep the 1 s periodic so the UI updates every second; the *value* must come from the clock delta, not an accumulator.
- Reset `_startedAt` on each `start()` (re-arm for repeated sessions — the channel re-arms too, `MeditationModuleStateChannel:42-45`).
- Dispose path already cancels the timer (`build()`'s `ref.onDispose`); leave it.
- Pure client-side; the server already trusts client start/end timestamps for `startedAt`/`endedAt` (note 137).

### Verify
- Start meditation, background/throttle ~30 s, return → `elapsedSeconds` reflects true wall-clock seconds, not a frozen lower count.

## Open Questions
- None.
