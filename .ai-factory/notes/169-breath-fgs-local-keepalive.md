# Re-point Android FGS keep-alive to the local lifecycle signal (offline fix) (T5)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- `KeepAliveCoordinator` (`lib/Core/Background/KeepAliveCoordinator.dart`) starts the Android FGS on the **server** event `ModuleSessionStarted` (`:28-29`) and stops on `Ended`/`Abandoned` (`:30-33`). Offline, `ModuleStateChannel` never confirms a session (`start()` drops the command when disconnected, `ModuleStateChannel.dart:205-211`), so `ModuleSessionStarted` never fires → the FGS never starts → a locked **offline** exercise freezes ~1 min after backgrounding.
- The fix is to drive the FGS from the **local** lifecycle signal (`BreathSessionState.isLive` from [[167-breath-derive-lifecycle-islive]]), which is true offline.
- This is the offline keep-alive gap that [[162-breath-audio-bounded-to-live-session]] / Phase 56 explicitly excluded (note 162 covers screen audio only).

## Details

The FGS coordinator lives in `lib/` and is wired in `App.initialize()` (subscribes to a global `ModuleStateEvent` stream); the breath activity lives in the package and is built per-screen. Bridge the local `isLive` transitions from the breath activity up to the app layer — either a local lifecycle-event stream off `BreathViewModel`, or the existing `attachModuleChannel` callback shape — and have `KeepAliveCoordinator` (or a thin breath-specific keep-alive coordinator) start/stop the FGS on local `isLive` ↑/↓ instead of the server event. Ensure it still **stops** on local complete/dispose (no orphan FGS — offline there is no server `Abandoned`).

## Guards

- Keep biometric streaming **server-gated** (`BiometricStreamClient` — do NOT move it to the local signal).
- Don't re-add Phase 51's running-session auto-`pause()`.
- Breath-only here. Meditation's Android FGS shares the same server-gated offline gap — note as future parity, out of scope.

## Verify

- Manual (device): airplane mode → start a breath session → lock → audio/guidance survive > 1 min; complete → FGS down; no orphan FGS after dispose.

## Open Questions

- Exact bridge shape (local event stream vs callback) — decide at `/aif-plan`; if [[171-breath-extract-owned-lifecycle-fsm]] lands first, the owned FSM can expose the transition directly.
