# Plan Review: Implement `AudioOneShot` in `mind_audio` (plan 21)

**Plan:** `.ai-factory/plans/21-implement-audiooneshot-in-mind-audio.md`
**Spec note:** `.ai-factory/notes/06-mind-audio-architecture.md` (§ `AudioOneShot`)
**Risk Level:** 🟢 Low

## Verdict

This is a minimal, faithful mechanical extraction of the existing tick-player primitive into the `mind_audio` package. The two-task plan matches:
- The public API shape declared in the architecture note (`load`, `play`, `stop`, `dispose`).
- The actual source patterns in `BreathSoundCoordinator.dart` — `_loadTickAsset` (line 219–223), `_onTick` body (line 235), and the `unawaited(_tickPlayer?.stop())` / `unawaited(tickPlayer.dispose())` calls at lines 126, 162, 156.
- The barrel-export convention already established by `audio_track.dart`, `audio_catalog.dart`, `audio_looper.dart` in `packages/mind_audio/lib/mind_audio.dart`.

`just_audio: ^0.10.5` is already a direct dependency of `packages/mind_audio` (confirmed in its `pubspec.yaml`), so no manifest edits are needed and the plan does not attempt any. No `audio_one_shot.dart` exists yet — clean greenfield add.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — `mind_audio` package still not enumerated in the modules table (same gap flagged in the AudioLooper review #19). This plan does not surface a new external consumer either, so it is non-blocking; defer until the coordinator-side rewrite milestone that wires `AudioOneShot` + `AudioLooper` into `BreathSoundCoordinator`.
- **Rules (`.ai-factory/RULES.md`):** PASS — `AudioOneShot` is not a Module Service, has no `IXxxService` interface, no notifier wiring, no Riverpod surface. The "stateless services" and "constructor injection" rules do not apply. The class has zero dependencies; `load(source)` is the explicit handoff, matching the pattern adopted by `AudioLooper`.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Not blocking. Consistent with the `mind_audio` extraction milestone series (plans 16–19, note 06).

## Findings

### Critical Issues

None.

### Minor / Should-clarify

1. **API divergence between `AudioOneShot` (sync `play`/`stop`) and `AudioLooper` (sync but uses internal `unawaited` wrappers similarly).**
   The plan returns `void` for `play`, `stop`, and `dispose`, mirroring `AudioLooper`'s fire-and-forget pattern. This is intentional and consistent — worth a one-line note in the class dartdoc that errors thrown from the wrapped futures are intentionally swallowed (e.g. "Errors from internal `seek`/`play`/`stop`/`dispose` futures are swallowed; this primitive optimises for low-latency fire-and-forget over error propagation."). Not blocking; future implementers and reviewers will benefit from the contract being explicit.

2. **`load()` can be called multiple times — behavior not specified.**
   The current coordinator calls `_loadTickAsset` again when `state.tickSource` changes (line 174–177). `AudioPlayer.setAudioSource` handles reload by replacing the source. The plan does not call this out. Optional one-liner in `load()`'s dartdoc: "Safe to call repeatedly to swap sources; replaces the previously buffered source." Otherwise an implementer might add a one-shot guard that prevents tick-source switching.

3. **No guard on `play()` before `load()` has resolved.**
   If a caller invokes `play()` before `load()` completes (or without calling `load()` at all), `seek(Duration.zero).then((_) => play())` is dispatched on an empty player. `just_audio` will either throw or no-op silently depending on platform. The original `_onTick()` had a null guard on `_tickPlayer`, not a load-state guard — so the source code shares this gap. Pick one of: (a) explicit "caller contract: call `play()` only after `load()` completes" in dartdoc, (b) ignore — domain-free primitive, caller owns sequencing. Either is fine; just be explicit so an implementer doesn't add an inconsistent guard.

4. **`dispose()` does not null the `_player` field, unlike `AudioLooper.dispose()`.**
   `AudioLooper.dispose()` nulls all its player refs to make follow-on calls observable / safe. `AudioOneShot._player` is `final` and non-nullable — so it cannot be nulled. This means a `play()` after `dispose()` will dispatch on a disposed `AudioPlayer` and throw. Inconsistent with `AudioLooper`'s teardown semantics but acceptable for a one-field primitive. Worth one of:
   - Declare in dartdoc: "After `dispose()`, the instance is unusable; calling any method results in undefined behaviour."
   - Or: change the field to `AudioPlayer? _player` and null it in `dispose()`, with null-checks on `play`/`stop`. The plan picks the simpler design — acceptable, just make the contract explicit.

5. **Task 1 dartdoc instruction "concise dartdoc on the class describing the pre-buffer + seek-and-go contract" is good but could specify "and the lifecycle contract: `load` → `play*` → `stop`/`dispose`" so the implementer doesn't omit it.**
   Trivial wording tightening.

6. **`unawaited` import.**
   The plan correctly states `dart:async` provides `unawaited`. Verified — `AudioLooper` uses the same import. No issue, just confirming.

### Positive Notes

- Faithful 1:1 mapping from the source coordinator's tick-player code to the new primitive. Each line cites the source line number it mirrors — easy to verify.
- Correctly avoids:
  - Asset path knowledge (caller supplies an `AudioSource`).
  - Tick-source switching guard (domain concern, stays in coordinator).
  - `allowTick` predicate (domain concern, stays in coordinator).
  - `kDebugMode` / `debugPrint` calls — consistent with the "Logging: minimal" setting and the same omission made in `AudioLooper`.
- Eager field initializer for `_player` matches the simplest-possible-class style; default generative constructor is left implicit and explained.
- Barrel-export step is sequenced after the file creation (Task 2 depends on Task 1) and the proposed placement (after `audio_looper.dart`) keeps the looper / one-shot pair adjacent for readability.
- Spec note section `### AudioOneShot` (note 06, lines 51–64) is the precise ground truth and the plan reproduces its public surface exactly.
- No `pubspec.yaml` / `flutter pub get` work — correctly identified as unnecessary.

## Suggested Edits (non-blocking)

Fold these into the existing two tasks rather than adding new ones:

- Task 1 class dartdoc: append "Lifecycle: `load(source)` once (or repeatedly to swap), then `play()` any number of times; `stop()` and `dispose()` are fire-and-forget. Calling any method after `dispose()` is undefined behaviour. Internal futures' errors are swallowed."
- Task 1 `load` dartdoc: append "Safe to call repeatedly to swap sources."
- Task 1 `play` dartdoc: append one of the two contracts in finding #3 above (explicit "must be after load completes" OR "no-op if no source loaded yet, depending on `just_audio`").

None of these block implementation. They only prevent drift between implementer guesses and the spec's intent — same shape of nits as plan-review 19.

PLAN_REVIEW_PASS
