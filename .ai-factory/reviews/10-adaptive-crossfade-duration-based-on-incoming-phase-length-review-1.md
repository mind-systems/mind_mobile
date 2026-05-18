# Code Review: Adaptive crossfade duration based on incoming phase length

**Plan:** `.ai-factory/plans/10-adaptive-crossfade-duration-based-on-incoming-phase-length.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Scope of changes (git diff HEAD)

Code:
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` — added three `static const` tuning constants, a private `_computeFadeDuration` helper, and replaced the fixed `Duration(milliseconds: intervalMs)` argument at the two `_switchToPhase` call sites in `_onStateChanged`. Added two new `debugPrint` lines, one per call site, that include the computed fade duration.

Docs / planning:
- `.ai-factory/ROADMAP.md` — adds the milestone bullet for this work.
- New: plan file, two plan reviews. All informational.

No changes to `_switchToPhase`, `_fadePlayer`, `BreathSessionState`, the state machine, or any other module/file. Surface area is fully contained inside `BreathSoundCoordinator`.

## Static checks
- `flutter analyze packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` → **No issues found.**
- `pow` is available via the existing `dart:math` import at line 2 — no new import needed.

## Correctness verification

### Formula
`fadeMs = (k * pow(nextPhaseMs, 0.65)).clamp(min, max)` with `k=3.83`, `min=150`, `max=1500`.

| nextPhaseMs | raw | clamped |
|---:|---:|---:|
| 1000 | 341.4 | 341 |
| 2000 | 536.2 | 536 |
| 3000 | 705.5 | 706 |
| 4000 | 842.6 | 843 |
| 8000 | 1320  | 1320 |
| 10470 | 1500 | 1500 (cap onset) |

All values match the reference table written in the source comment (lines 56–61). ✓

### Type safety
- `_kFadeCoeff` is `double`; `pow(double, double)` returns `num`; `double * num` evaluates to `double` (per `double.operator*(num)`). So `raw` is `double`. ✓
- `raw.clamp(double, double)` on `double` returns `num`; `.toInt()` is valid. ✓
- `intervalMs.clamp(_kMinFadeMs, _kMaxFadeMs)` is `int.clamp(int, int)` → `int`, accepted by `Duration(milliseconds:)`. ✓

### State semantics at call sites
- `state.currentPhaseTotalDuration` is the **tick count** of the current phase, populated from `steps[currentPhaseIndex].duration` in `_computeEnrichedFields` (`BreathSessionStateMachine.dart:437–460`) and re‑emitted on each `_onBreathTick` / `start` / `resume`. So `phaseTicks * intervalMs = total phase duration in ms`. ✓
- At the **status→breath** call site (line 178–182), the state emitted on transition into `breath` already carries the enriched `currentPhaseTotalDuration` of the *incoming* phase (verified via grep — every emission path goes through the enriched fields). ✓
- At the **phase change** call site (line 198–201), the state emitted by `_onBreathTick` for the new phase carries the new phase's `currentPhaseTotalDuration`. ✓

### Edge cases
- `phaseTicks <= 0` fallback: returns `Duration(milliseconds: intervalMs.clamp(150, 1500))`. For a `currentIntervalMs == 1000` (clock tick) this yields 1000ms — matches the pre‑change behavior, so initial / error states degrade gracefully. ✓
- `intervalMs <= 0` guard: kept (`state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000`). ✓
- Very long phases (e.g. 60s): `pow(60000, 0.65) * 3.83 ≈ 4882`, clamped to 1500. ✓
- Very short phases (e.g. 500ms): below the math minimum, but the curve only produces values < 150 for `nextPhaseMs < ~50ms`, so any plausible phase length stays out of the `_kMinFadeMs` floor. The floor exists as a safety net rather than an active branch — fine.

### Behavior side effects
- The fade duration argument is used for **both** the outgoing fade (`_fadePlayer(active, 0.0, fadeDuration)` at line 239) and the incoming fade (line 265) inside `_switchToPhase`. After this change, a transition from a long phase to a short phase will fade the outgoing player out over the *short* duration (the incoming phase's curve value). This is the intended symmetric crossfade per the milestone, but worth flagging: on a 10s→1s transition the outgoing player will only have 341ms to fade out where it previously had ~1s. Audible delta is small and consistent with the stated UX intent ("perceptual feel across the full range") — non‑blocking.
- The other four `_fadePlayer` calls (pause 200ms, in‑phase volume bump 200ms, complete/rest 500ms, non‑phase‑asset 500ms) are untouched — those are fixed UX timings and correctly left alone.

### Concurrency
- `_computeFadeDuration` is synchronous, reads only the passed `state` (no shared mutation), and is called on the same isolate as the existing `_onStateChanged` listener. No new race surface introduced. ✓
- `_switchToPhase`'s existing `_switchGen` / `_loadFuture` guards are untouched. ✓

## Concerns

### 1. Outgoing fade is sized by the incoming phase (advisory, non‑blocking)
As noted in "Behavior side effects": the same `fadeDuration` value is reused for both the outgoing fade (started immediately, before `seek`) and the incoming fade (started after `play()`). When transitioning from a long phase to a short one, the outgoing player will be cut off faster than under the previous behavior. This matches the milestone's "perceptual feel" intent (short incoming phase ⇒ short crossfade overall) but worth documenting if perceived sharpness becomes an issue. No code change required — flagging for future tuning awareness.

### 2. Two duplicative log lines on the breath path (minor cosmetic)
The status‑change branch now emits two debug lines per transition into `breath` with a new phase: the existing top‑level status log at line 173, plus the new `status→breath switchToPhase` log at line 181. Similarly the phase‑change path emits the existing log at line 197 plus the new log at line 200. This is the *additive* approach suggested in plan‑review v2 (preserves observability for pause/rest/complete) and is fine — just slightly chatty. `_switchToPhase` then prints `fadeDuration=…ms` again at line 230. The redundancy is intentional (call‑site grepping convenience) and only fires in `kDebugMode`. Non‑blocking.

## Positive notes
- Constants are clustered with the other tuning maps and self‑documented with an accurate reference table — matches the file's style.
- Helper is a private synchronous method with no signature change to `_switchToPhase`; trivially reversible.
- Fallback for `phaseTicks <= 0` reuses the existing `intervalMs > 0 ? … : 1000` guard pattern from the file.
- Documentation drift inherited from the roadmap description was reconciled in the plan and the *correct* table written into the source comment.
- New debug logs are gated on `kDebugMode` like the rest of the file.

## Summary
The change is type‑safe, analyzer‑clean, and faithfully implements the plan. Both planned formula and call‑site replacements check out against the live `BreathSessionState` semantics. The only observations are advisory (symmetric crossfade sizing, log chattiness) and explicitly within the milestone's stated design intent.

REVIEW_PASS
