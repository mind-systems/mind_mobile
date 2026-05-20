# Plan Review: Implement `AudioLooper` in `mind_audio` (plan 19)

**Plan:** `.ai-factory/plans/19-implement-audiolooper-in-mind-audio.md`
**Spec note:** `.ai-factory/notes/09-audio-looper.md`
**Risk Level:** 🟢 Low

## Verdict

The plan is a faithful, well-scoped mechanical extraction. File paths, public-API shape, internal field names, dependency order between tasks, and the export step all line up with the spec note and the source code in `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`. `just_audio: ^0.10.5` is already a direct dependency of `packages/mind_audio` (verified in `pubspec.yaml`), so no manifest edits are needed and the plan's "no `pubspec.yaml` edits" assertion in Task 5 is correct.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — `mind_audio` is not yet enumerated in the modules table. The plan does not require us to update ARCHITECTURE.md (this is an internal helper inside an existing package) but the next milestone that introduces a public consumer is a good moment to surface it.
- **Rules (`.ai-factory/RULES.md`):** PASS — `AudioLooper` is not a Module Service (no `IXxxService`, no notifier wiring). The "stateless services" rule does not apply. Constructor-injection rule does not apply either — `AudioLooper` has no dependencies; `initialize(sources)` is the explicit handoff.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Not blocking. Plan references Phase 13 / note 09.

## Findings

### Critical Issues
None.

### Minor / Should-clarify

1. **Task 4 — `dispose()`: explicitly null fade-timer fields after cancel.**
   The plan says "cancel both fade timers, capture both player refs locally, null all fields (`_playerA`, `_playerB`, `_activePlayer`, `_inactivePlayer`, `_loadFuture`)" but does not list `_fadeTimerA` / `_fadeTimerB` among the nulled fields. The source coordinator does both (`_fadeTimerA?.cancel(); _fadeTimerA = null;` — lines 135–138). Add timer fields to the null-out list for symmetry with the original. Otherwise a later `_cancelFadeFor` would be a no-op cancel on a stale ref — harmless but inconsistent with the source.

2. **Task 4 — `fadeOut` / `fadeIn` use `_activePlayer!`.**
   Inherited from the spec note: if a caller invokes `fadeOut`/`fadeIn` before `initialize`, this null-asserts and throws. The original `BreathSoundCoordinator` guards with `if (_activeLoop != null)` before calling `_fadePlayer`. Worth either (a) keeping the bang-on-null contract and documenting "must be called after `initialize`" in a one-line `///` comment on these methods, or (b) silently no-op'ing when `_activePlayer == null`. Either is fine; the plan should pick one explicitly so the implementer doesn't add an inconsistent guard.

3. **Task 3 — `crossfadeTo` does not validate `index`.**
   The original computed `index = _phaseOrder.indexOf(phase)` and bailed on `-1`. The new API receives `int index` from the caller. This is correct for a domain-free utility, but a one-line note in Task 3 — "no `index` validation here; `inactive.seek(index: index)` will throw if out of range; caller is responsible" — would prevent an implementer from re-adding a guard "to be safe."

4. **Task 4 — `stop()` does not bump `_switchGen`.**
   Inherited behaviour: the original `reset()` does not bump `_switchGen` either, and any pending IIFE inside `crossfadeTo` could still run to completion after `stop()` and re-set `_activePlayer` based on stale local refs. `_cancelFadeFor` is called by `stop()` so no fade timer survives, but the gen check inside the IIFE will not trip. This is consistent with the source, so the plan is not wrong — just worth being aware of so the future coordinator-side rewrite (next milestone) doesn't accidentally rely on a "stop cancels in-flight crossfades" guarantee that doesn't exist.

5. **Plan §Context wording.**
   "concurrent-call guard moves here" is accurate; consider also stating explicitly that the **second** gen check (the one after the `play()` dispatch, line 273 in the source) is preserved here too — Task 3 covers this in the invariants list, so the context paragraph is fine, just a minor redundancy that could help reviewers skimming the top.

### Positive Notes

- Plan correctly identifies that domain bails (`_currentStatus != BreathSessionStatus.breath`, the `_phaseAssets[phase] == null` and `index == -1` guards) stay in the coordinator and do NOT move into `AudioLooper`. This is the easiest place for an extraction plan to go wrong, and the plan calls it out twice (Task 3 final sentence and Context paragraph).
- Plan correctly preserves the Phase 12 invariants:
  - Early synchronous fade-out before any `await`.
  - `unawaited(inactive.play())` — never await.
  - Gen check both after `_loadFuture` and after the swap.
- Plan correctly removes `kDebugMode`/`debugPrint` calls and notes "Settings: Logging: minimal" — the diagnostics in the source were coordinator-level and would be noise inside a generic utility.
- Task dependencies are sequential and accurate (`Task N depends on Task N-1`); no parallelism overstated.
- Task 5 correctly identifies that no `flutter pub get` / `pubspec.yaml` edits are required because `just_audio` is already declared.
- Spec note `.ai-factory/notes/09-audio-looper.md` is precise enough to serve as the implementation ground truth, and the plan references it specifically (line and section pointers).

## Suggested Edits (non-blocking)

If you want to tighten the plan before handing it to `/aif-implement`, fold these into the existing tasks rather than adding new ones:

- Task 4 bullet for `dispose()`: append "and `_fadeTimerA`/`_fadeTimerB`" to the field-nulling list.
- Task 4 bullet for `fadeOut`/`fadeIn`: add a sentence "Caller contract: must be invoked after `initialize`; null-asserting `_activePlayer!` matches the spec."
- Task 3 final paragraph: add "No `index` bounds check — caller owns validation."

None of the above block implementation; they only prevent drift between implementer guesses and the spec's intent.

PLAN_REVIEW_PASS
