# Plan Review: Meditation iOS silent keep-alive loop

**Plan:** `.ai-factory/plans/76-meditation-ios-silent-keep-alive-loop.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — no blocking issues found.

## Verification Summary

Every factual claim in the plan was checked against the actual code:

| Claim in plan | Verified |
|---|---|
| `pubspec.yaml` declares `assets/audio/` under `flutter: assets:` | ✅ Confirmed (line ~123). Wildcard directory entry → `silence.flac` will be bundled with no extra entry needed. |
| Asset-path string format `assets/audio/silence.flac` | ✅ Matches existing usage (`assets/audio/ohm_inhale.flac` in `BreathSoundCoordinator`, `AudioTrack` doc). |
| `AudioOneShot` is the right model for `SilentKeepAlivePlayer` | ✅ Confirmed — single `AudioPlayer`, fire-and-forget `play()`/`stop()`/`dispose()` with `logPrint` on failure. |
| `mind_audio` barrel pattern (`export 'src/...'`) | ✅ Confirmed in `mind_audio.dart`; `mind_audio` already depends on `mind_logger` (used by `AudioOneShot`). |
| `LoopMode.one` is the correct loop API | ✅ Confirmed — `AudioLooper` uses `setLoopMode(LoopMode.one)`. |
| `MeditationModuleStateChannel` is the right template for the coordinator | ✅ Confirmed — `_previousStatus` transition-edge pattern, `show`-import of `MeditationSessionState`/`MeditationSessionStatus`, `dispose()` cancels sub. |
| `vm.stream` exists and is the same stream the channel uses | ✅ `MeditationSessionViewModel.stream` → `StreamController<MeditationSessionState>.broadcast()`. |
| `MeditationModule.buildSession` is the assembly point | ✅ Confirmed — `late final stateChannel` created inside `overrideWith`; `MeditationSessionScreen(onDispose: …)` teardown hook exists. |
| `MeditationSessionScreen` exposes `onDispose` called from `State.dispose()` | ✅ Confirmed (`MeditationSessionScreen.dart:33`, inside `dispose()`). |
| iOS audio session foundation (`playback` + `mixWithOthers`, `UIBackgroundModes: [audio]`) | ✅ Confirmed — `configureAudioSession()` called once in `App.initialize()` (App.dart:148); Info.plist has `audio`. |
| Roadmap linkage | ✅ Maps 1:1 to Phase 51 task "Meditation iOS silent keep-alive loop" (note 142). Plan matches spec note `.ai-factory/notes/142-…` with no divergence. |

## Context Gates

- **Architecture:** No boundary violations. Coordinator lives in `lib/MeditationModule/Core/` (domain/wiring layer), `SilentKeepAlivePlayer` stays asset-agnostic in `mind_audio` (constructor-injected `assetPath`), preserving the package's decoupling from app asset names. ✅
- **Rules:** Compliant. Rule 3 (constructor injection) — both `stateStream` and `player` injected; the coordinator owns its own subscription. Rule 2 (no module wiring in `App.dart`) — all wiring stays in `buildSession`. Rule 1 (stateless Module Services) — N/A; this is a coordinator, not an `IXxxService`. ✅
- **Roadmap:** Linked and current (Phase 51, the only unchecked task in that phase). ✅

## Critical Issues

None.

## Correctness Notes (non-blocking)

1. **Broadcast stream / second listener — safe.** Adding the keep-alive coordinator as a *second* subscriber to `vm.stream` is fine because `_stateController` is a `broadcast()` controller; `MeditationModuleStateChannel` is already the first listener. No "Stream already listened to" risk. The broadcast stream does **not** replay the initial `idle` state, but the coordinator subscribes at VM creation (before `start()` is called), so it reliably catches the `idle → active` edge — identical to the proven `MeditationModuleStateChannel` flow. Worth keeping this in mind during implementation, but no change required.

2. **Volume-0 guard is genuinely harmless for keep-alive.** Setting player volume to 0 does not defeat iOS background continuation: the session stays active as long as the player feeds samples to the output, regardless of software gain. Since the asset is digital silence, volume 0 and volume 1 are audibly identical anyway. The belt-and-suspenders guard is safe; just don't expect the *volume* (vs. the active session) to be what holds the process alive.

3. **Loop length (optional polish).** A ~4 s loop with `LoopMode.one` is acceptable (breath loops use the same mode). If the loop boundary ever proves to introduce a perceptible gap that lets iOS nap, a longer asset (e.g. 20–30 s) reduces boundary frequency at negligible bundle cost. Not required for first cut.

4. **Teardown idempotency.** On normal completion the coordinator calls `player.stop()` at `idle`, then the screen's `onDispose` calls `keepAlive.dispose()` → `player.stop()` + `dispose()`. The double `stop()` is idempotent on `just_audio`. Fine. Ensure `dispose()` is null-safe on the coordinator reference (the plan already specifies this — coordinator only exists on iOS).

## Positive Notes

- Strong, accurate codebase grounding — every referenced file, line, and pattern checks out.
- Correctly identifies that the iOS background-audio foundation (note 138) is already in place, so this task is purely additive.
- Keeps `SilentKeepAlivePlayer` asset-agnostic, mirroring `AudioLooper`/`AudioCatalog` injection style and preserving package decoupling.
- Platform guard (`Platform.isIOS`) is correctly scoped: Android is covered by the FGS (note 139), so no redundant player there.
- Respects RULES.md (constructor injection, no `App.dart` wiring) and the established coordinator/transition-edge pattern.

PLAN_REVIEW_PASS
