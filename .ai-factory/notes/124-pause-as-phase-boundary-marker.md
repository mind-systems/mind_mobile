# Emit pause/resume as `breath_phase` boundary markers on the offset timeline

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- Today a pause is only a **server lifecycle event** (`BreathModuleStateChannel._handleLifecycle` calls `_channel.pause()` → server PAUSED, stamped on the server clock). It never appears on the instruction (phase) timeline, so the breath chart has no pause region.
- `BreathModuleStateChannel._handleInstruction` returns early for non-active states (`if (!isActive ...) return;`, line 92), and on resume the phase is unchanged so `phaseChanged` is `false` — neither pause entry nor resume re-emits a phase marker today.
- **Server reality (blocker):** even if mobile emits the markers, `mind_api module-instruction-stream.grpc.controller.ts:103-115` rejects any `breath_phase` instruction while `session.isPaused` with `SESSION_PAUSED`. The **resume** marker is blocked **deterministically** — on resume the server is still `isPaused=true` (the RESUMED lifecycle has not flipped it yet) and the marker is `breath_phase`. So note 124 depends on the server pause-guard removal (`mind_api` note 49). With that guard gone, the markers ride the existing `breath_phase` contract — **no new `instructionType` and no dodge needed**.
- With the continuous offset axis (note 121) and biometrics flowing through pause (note 123), the pause interval should be a first-class **phase band** on the same axis. Emitting `phase='pause'` boundary markers into the existing `breath_phase` stream achieves this with no new instruction type — mind_web already draws a bar from each `breath_phase` offset to the next.
- The server lifecycle PAUSED event stays as-is: it lives on a different axis (server wall-clock) and serves status/bookkeeping. The phase marker serves timeline geometry. They are not redundant.

## Details

### The change (`lib/BreathModule/Core/BreathModuleStateChannel.dart`)
1. On the active→pause transition in `_handleLifecycle` (the `wasActive && status == pause` branch), in addition to `_channel.pause()`, emit a boundary marker via the instruction stream with `phase='pause'` at the current `offsetMs` (from the note-121 `Stopwatch`). `tickCount` for a pause marker is meaningless — send `0` (or omit and let the consumer treat absent as `0`).
2. On resume (the `wasPaused && isActive` branch where `_started` is already true), explicitly emit the resumed phase marker at its `offsetMs` — do **not** rely on `phaseChanged`, because the phase is the same as before the pause so `_handleInstruction` will not fire. After emitting, set `_previousPhase`/`_previousExerciseIndex` so the next natural phase change still diffs correctly.
3. The pause marker rides the existing `sendSample` (string `phase` param already accepts arbitrary values — `'pause'` is not a `BreathPhase` enum member, and that is fine since the wire carries a string).

No terminal/end marker is emitted. Bounding the last bar is a **consumer (mind_web) concern**, handled via session end (`endedAt − startedAt`) — see Cross-repo coupling.

### Dependencies
- `mind_api` note 49 (`49-realtime-accept-samples-through-pause.md`) — the server instruction pause-guard removed. Without it the resume marker is rejected deterministically (see Key Findings). Deploy order: **server → mobile**.
- Note 121 (offset axis + `{phase, tickCount, offsetMs}` contract) — the `Stopwatch` and the `offsetMs`-based `sendSample` signature come from there.
- Pairs with note 123 (bio through pause) so the pause band carries biometric data; either can ship first.

### Cross-repo coupling
- mind_web needs a color/label for `data.phase === 'pause'` in its phase renderer. Track in mind_web's roadmap. Absent that, web renders the pause as an unstyled/default bar — not broken, just uncolored.
- mind_web bounds the last bar (phase or pause) by session end = `endedAt − startedAt` (a single internally-consistent server scalar — the per-sample cross-clock skew does not apply to a scalar axis extent; error vs the true client offset-end is RTT-scale), for **all** session statuses. No mobile marker is emitted for this, and abandoned/disconnected sessions are **not** special-cased (their `endedAt` may carry a grace/disconnect tail — accepted for simplicity; matches mind_web note 23).

### Guards
- No new `instructionType`; reuse `breath_phase`/`data`.
- Do NOT alter or remove the server lifecycle PAUSED event (`_channel.pause()`/`unpause()`); it stays for status/recovery.
- Watch the resume re-emit interacting with `_previousPhase` bookkeeping so a post-resume real phase change is not swallowed.

## Open Questions

- None.
