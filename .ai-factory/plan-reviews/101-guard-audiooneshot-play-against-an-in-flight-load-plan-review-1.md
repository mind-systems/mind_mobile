# Plan Review: Guard `AudioOneShot.play()` against an in-flight `load()` (plan 101)

**Plan:** `.ai-factory/plans/101-guard-audiooneshot-play-against-an-in-flight-load.md`
**Spec note:** `.ai-factory/notes/47-task-audio-oneshot-load-guard.md` (Phase 26; note 42 Task 2)
**Target file:** `packages/mind_audio/lib/src/audio_one_shot.dart`
**Risk Level:** 🟢 Low

## Verification Against Codebase

- **File path** — Correct. `packages/mind_audio/lib/src/audio_one_shot.dart` exists and contains the exact `load()`/`play()` shape the plan describes (`load` awaits `setAudioSource`, `play` fires `unawaited(_player.seek(Duration.zero).then((_) => _player.play()))`).
- **Race is real** — Confirmed in `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`. `_onStateChanged` fires `_oneShot.load(src)` via an unawaited `.then(...)` chain on a tick-source change (lines 167–174), while `_onTick` calls `_oneShot.play()` (line 234) off the tick stream. The two can interleave on the same `AudioPlayer`, exactly as the spec states.
- **Caller-safety claim** — Correct. The change is purely internal to `AudioOneShot`; no signature or behavior change is visible to `BreathSoundCoordinator` or to `BciCalibrationSection` (the only other `AudioOneShot` consumer, `packages/bci_module/.../BciCalibrationSection.dart`), which loads once and never re-loads, so the guard is a no-op there.
- **No barrel change needed** — Correct. `packages/mind_audio/lib/mind_audio.dart` already exports `src/audio_one_shot.dart`; the public surface is unchanged, so no export edit is required. The plan rightly omits one.
- **`finally` semantics** — Correct. Wrapping only the `await _player.setAudioSource(source)` in try/finally clears `_loading` even if `setAudioSource` throws, preventing a permanent stuck-guard that would silence all subsequent ticks.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — PASS / WARN (non-blocking). `AudioOneShot` is a leaf primitive in `mind_audio`; the change introduces no new dependency, boundary crossing, or module wiring. (The long-standing "`mind_audio` not enumerated in the modules table" gap noted in earlier reviews is pre-existing and out of scope here.)
- **Rules (`.ai-factory/RULES.md`)** — PASS. None of the three rules apply: `AudioOneShot` is not a Module Service (no `IXxxService`), touches no App.dart state, and adds no externally-wired dependency. The `_loading` field is private internal state of a mechanics primitive, which the "stateless Module Services" rule does not govern.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — PASS. Line 237 is this exact task and points at spec note 47. Plan ↔ roadmap ↔ spec are aligned.

## Observations (non-blocking)

- **Overlapping `load()` calls.** If two `load()` calls overlap (e.g. a rapid double tick-source toggle), the first call's `finally` clears `_loading` while the second `setAudioSource` is still in flight, briefly re-opening the window. This is an extremely rare path (tick source is described as "stable within a session"), and the worst case is precisely the already-accepted degradation — a single tick played during a buffer swap. No action needed; flagging only for completeness. A future hardening could use a token/counter instead of a bool, but that exceeds this task's scope and the spec's intent.
- **Logging.** Plan settings say "minimal" logging and the task adds none. The file currently has no logging, and `play()` is a hot path (per-tick); adding a `debugPrint` inside the guard would be noisy. Omitting logging is the right call here and consistent with "minimal."

## Conclusion

The plan reproduces the spec note one-to-one, targets the correct single file, correctly identifies the racing caller, makes no public-API or caller changes, and uses `finally` to avoid a stuck-guard failure mode. Scope is appropriately minimal (one field, two small edits). No missing steps, no wrong assumptions, no incorrect paths or API usage.

PLAN_REVIEW_PASS
