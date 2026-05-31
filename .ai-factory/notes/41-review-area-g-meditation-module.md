# Code Review — Area G: Meditation Module (Phase 25)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `lib/MeditationModule/{MeditationModule,MeditationListService,*Coordinator,Core/MeditationModuleStateChannel}.dart`, `packages/meditation_module/lib/src/*`

## Verdict

The copy-paste-strip from the breath module is clean and the single-session happy path works: idle→active starts the shared `ModuleStateChannel` with `ActivityType.meditation`, active→idle ends it, dispose stops an in-progress one, and biometrics record automatically via the already-wired pipeline. **But the lifecycle adapter doesn't survive a second session in the same screen mount** — a real, reachable data-loss bug.

## Key Findings

- **[Medium] Repeat Start→Stop→Start in one screen visit silently records nothing after the first session.** `MeditationModuleStateChannel` uses one-shot `_started`/`_ended` flags that **never re-arm**. The session UI is a plain Start/Stop toggle on a persistent `MeditationSessionViewModel` (`start()` → active, `stop()` → idle), so a user can run multiple cycles without leaving the screen. On the 2nd `active`: `!_started` is false → `_channel.start()` is **not** called; `_ended` is true → the idle branch is a no-op; and `dispose()`'s `_started && !_ended` is false → no `_channel.stop()`. Net effect: the 2nd+ meditation sessions emit **no** lifecycle events, and because `BiometricStreamClient._currentSessionId` was cleared on the 1st `end`, **no biometrics are recorded either** — the session is completely invisible to the backend. The breath module avoids this with a `reset()` that re-arms `_started`/`_ended` on restart; the meditation copy intentionally dropped `reset()` ("NO reset()" in the spec) without accounting for the toggle being re-pressable. **Fix:** on the active→idle transition, after `_channel.end()`, also reset `_started = false; _ended = false;` so the next `active` re-arms.

- **[Low / edge] `late final stateChannel` can throw `LateInitializationError` on dispose if the session provider is never read.** In `MeditationModule.buildSession`, `stateChannel` is assigned inside the `overrideWith` factory and referenced by the screen's `onDispose`. If the screen is torn down before the provider is first read, the field is unassigned. The screen reads the VM during build, so the factory runs first in practice — and this mirrors the breath module's pattern exactly — but it's a latent edge.

## Details

### Verified correct (single-session path)
- `MeditationModuleStateChannel._onState`: dedups on `status == _previousStatus`; idle→active → `start(type: meditation, refId: poseId)` once; active→idle → `end()` once; `dispose()` → `stop()` when `_started && !_ended` (covers "navigated away mid-session").
- `ActivityType.meditation` is mapped to `proto.ActivityType.MEDITATION` in `ModuleStateChannel._mapActivityType` (Phase 25 task), and the proto stub carries `MEDITATION = 2`.
- `MeditationSessionViewModel`: dual-channel `set state` (raw `_stateController` broadcast + `super.state`), controller closed in `build()`'s `ref.onDispose` — mirrors the breath VM minus tick filtering.
- Biometrics need no new wiring: the shared `App.shared.moduleStateChannel` gates `BiometricStreamClient`, so a tracked meditation session streams BCI data for free. (This is exactly why the re-arm bug also kills biometrics for repeat sessions.)
- Static pose list + `meditationPoseTitle(l10n, id)` switch helper; list/session coordinators are thin `context.push`/`context.pop` wrappers. No persistence/notifier/Drift, as designed.

## Open Questions

- Confirm the intended UX: is Start→Stop→Start in one screen visit a supported flow (then the re-arm fix is required), or should Stop navigate away / disable restart (then the UI must enforce it)? Given the screen stays mounted and the button flips back to "play", re-arming is the lower-friction fix.
