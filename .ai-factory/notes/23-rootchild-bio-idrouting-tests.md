# Root/child — bio id-routing red tests (TDD-first for note 17)

**Date:** 2026-07-02
**Source:** conversation context; `roadmap-decompose-skeleton` pass over Phase 63

## Key Findings

- Retargeting bio to `root.id` (note 17) is a **silent-failure** surface: if the id source or the clear-conditions are wrong, samples are tagged with the wrong session and analytics corrupt with **no crash**. Per test-philosophy, test it.
- The dangerous point is **stateful**: bio must **NOT** clear `_currentSessionId` on a child's `Ended`/`Abandoned` (only on global reset / root gone). A stateless test double would let a "clears on child end" regression pass (m36 canon) — the test must drive the real clear-condition state.
- Tests-first as their own milestone; note 17 turns them green.

## Details

### Red tests (against `BiometricStreamClient` + the phase path)
- **bio carries `root.id`:** with a root open and a breath child live, an emitted `BioSample` has `sessionId == root.id`, not the breath child id (`BiometricStreamClient.dart:215-222`).
- **child end does NOT stop bio:** after the breath child ends (`ModuleSessionEnded`), bio still sends under `root.id` — `_currentSessionId` is unchanged (contrast current `:100-104` which clears it).
- **global reset DOES clear bio:** on the `AllSessionsReset` event (note 20), `_currentSessionId` is cleared and the replay ring emptied.
- **gate holds:** no bio is sent before `rootId` is known / `_sessionConfirmed` (`:111`).
- **phase stays on child:** a phase/instruction sample carries the **child** id, not `root.id` (`BreathModuleStateChannel.dart:131`) — asserts the two id sources stay decoupled.
- **late phase dropped:** a phase sample after its child ended → `SESSION_NOT_FOUND` is swallowed (no throw, no user error).

### Guards
- Drive the real clear-condition state (stateful), not a pass-through double.
- Do not assert on proto encoding (loud); assert on which id is chosen.

### Verify
- Tests RED against the current current-activity-sourced id; go green under note 17.
