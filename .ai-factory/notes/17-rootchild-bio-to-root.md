# Root/child — retarget the bio stream to `root.id`

**Date:** 2026-07-02
**Source:** conversation context; handoff §7; `mind_api/.ai-factory/notes/35-generalize-bio-ingest-ownership.md`

## Key Findings

- Bio binds to the **root** timeline. `BioSample.session_id` must carry `root.id` (from note 15), not the current activity's id. The server resolves the root from `userId` and is tolerant of the echo, but the client should send the real root id.
- Today the bio client tags samples with `_currentSessionId`, sourced from the **current activity** lifecycle (`ModuleSessionStarted`/`Resumed` → set; `Ended`/`Abandoned` → null). That is the wrong axis under root/child — bio would stop when a child ends even though the root (and bio) continues.
- `module_biometric_stream.proto` did **not** change — this is purely which id the client puts in `session_id`.
- Depends on notes 14, 15.
- **This is the IMPL milestone.** The RED id-routing tests (bio=root, phase=child, no-clear-on-child-end, late `SESSION_NOT_FOUND` dropped) are a **separate TDD-first milestone (note 23)** laid first; this task turns them green.

## Details

### Current state (exact)
- `lib/Biometrics/BiometricStreamClient.dart`: sample id injected at wire-encode time `:215-222` (`sessionId: sessionId`, read from `_currentSessionId` at `:200`); source `_onLifecycleEvent` `:86-106` (`ModuleSessionStarted` → `_currentSessionId = moduleSessionId` `:88-90`; `ModuleSessionResumed` `:92-95`; `ModuleSessionEnded || ModuleSessionAbandoned` → `null` + `_replayRing.clear()` `:100-104`); send gate `:111` `if (_currentSessionId == null || !_sessionConfirmed) return;`; also `disconnect` clears `_sessionConfirmed` `:76-77`.
- Phase tagging is a **separate** path: `BreathModuleStateChannel` sends phase samples with its own `_moduleSessionId` via `_instructionStream.sendSample(...)` at `BreathModuleStateChannel.dart:72`, `:131`, `:138`; `_moduleSessionId` is set from `channel.state` at `:46`. This never touches `BiometricStreamClient._currentSessionId` — the two ids are already decoupled.

### Change
- Source `_currentSessionId` from the **root** id (`RootStateChannel.rootId` / registry `rootId` getter, notes 14/15) instead of the current-activity lifecycle events. Concretely: subscribe bio to the root-id stream and set `_currentSessionId = rootId`; set `_sessionConfirmed = true` when `rootId` is known.
- **Change the clear conditions:** the `ModuleSessionEnded || ModuleSessionAbandoned` case (`:100-104`) must **no longer** clear `_currentSessionId` on a child's end — only clear on the new global-reset event (`AllSessionsReset`, note 20) or when `rootId` goes null. Keep the `disconnect` path clearing `_sessionConfirmed` (`:76-77`) and re-arming on reconnect (root id re-learned via note 15 re-open).
- Keep the `_sessionConfirmed` + `_currentSessionId != null` gate (`:111`); "root id known" is the precondition (bio held until root open, note 15).

### Guards
- Do not clear the bio session id on child `Ended`/`Abandoned` — bio must keep flowing under the root while other children (or none) run.
- Send the real `root.id`; rely on server tolerance only as a safety net, not as the contract.
- **Only bio moves to `root.id`. Phase/instruction markers stay on the CHILD id.** `BreathModuleStateChannel` tags phase samples with its own child id (`childOfType(breath)`, note 14) via `_moduleSessionId` (`BreathModuleStateChannel.dart:131` → `BreathModuleInstructionStream.sendSample`); this is a **different** source than bio's `BiometricStreamClient._currentSessionId`, so retargeting bio must NOT touch the phase-tagging id. If any refactor were to share one session-id source between bio and phases, decouple them here — misrouting phases onto the root silently corrupts the instruction timeline (bio = root, phases = child).
- A late phase sample arriving after its child ended is rejected `SESSION_NOT_FOUND` — drop it silently (no error surfaced), it is a benign race.

### Verify
- Bio samples during a breath child carry `root.id`, not the breath child id.
- Phase samples during that same breath child still carry the **breath child id**, not `root.id`.
- A child ending does not stop bio; bio stops only on abandoned-tree / disconnect.
- No bio is sent before `rootId` is known.
