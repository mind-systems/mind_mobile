# Plan Review: Migrate ohm loop files to FLAC and remove encoder-delay workaround

## Plan Reviewed
`.ai-factory/plans/25-migrate-ohm-loop-files-to-flac-and-remove-encoder-delay-workaround.md`

## Risk Level
🟢 Low — three localized edits, no consumers outside the listed files, FLAC assets already in place.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — OK. The change stays within the `mind_audio` package and one coordinator inside `breath_module`; module boundaries (domain ↔ module) are unaffected. No new cross-layer dependencies introduced.
- **Rules (`.ai-factory/RULES.md`)** — OK. The three rules in `RULES.md` (stateless services, no module state in `App.dart`, constructor injection) are not in scope; `AudioTrack` / `AssetAudioCatalog` are pure value/builder classes and the coordinator's DI is unchanged.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — Linked. Matches milestone "Migrate ohm loop files to FLAC and remove encoder-delay workaround" in Phase 13 (continued, line 53). The plan correctly flags the divergence between the milestone wording (`.wav`) and the live code (`.opus`) and resolves it in favor of the real file paths. WARN: when the implementation is done, the roadmap bullet's `ohm_*.wav` wording should be normalized — but that is a roadmap-prune concern, not a blocker for this plan.

## Verification Against Current Code

- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart:31–36` — `_phaseAssets` map currently holds `assets/audio/ohm_inhale.opus`, `ohm_exhale.opus`, `ohm_hold.opus`. The plan's described starting state and the line reference ("around line 31") are accurate. `_tickAssets` at 46–49 keeps `tick_clock.ogg` / `tick_heartbeat.ogg`; the plan correctly leaves them alone.
- `packages/mind_audio/lib/src/audio_catalog.dart` — file imports `dart:convert`, `package:flutter/services.dart`, `package:just_audio/just_audio.dart`; `sourceFor` body matches the plan's described shape (try/catch around `rootBundle.loadString`, `jsonDecode`, `loopEndMs` branch, `ClippingAudioSource` wrap). After the edits described in Task 2 the remaining `just_audio` import is still required (for `AudioSource`), which the plan explicitly preserves. ✅
- `packages/mind_audio/lib/src/audio_track.dart` — the `loopEnd` field and named-parameter constructor exist as the plan describes. `@immutable` plus `package:flutter/foundation.dart` are present and the plan correctly preserves them. ✅
- Call-site audit for `AudioTrack(...)`: only three live invocations exist, all inside `BreathSoundCoordinator.dart` (lines 95, 101, 148), and all are positional — `AudioTrack(_phaseAssets[p]!)` / `AudioTrack(_tickAssets[_currentTickSource]!)`. Dropping the named `loopEnd:` parameter cannot break any caller. ✅
- Symbol audit for the workaround vocabulary (`ClippingAudioSource`, `meta.json`, `loop_end_ms`, `loopEnd`) across the repo `.dart` tree: matches occur only in `audio_catalog.dart` and `audio_track.dart`. No orphaned references will remain after these two files are edited. ✅
- Assets: `ls assets/audio/` confirms `ohm_inhale.flac`, `ohm_exhale.flac`, `ohm_hold.flac`, `tick_clock.ogg`, `tick_heartbeat.ogg` — no `.opus` or `.meta.json` remnants. The plan's claim that the FLAC files are already bundled is accurate.
- `pubspec.yaml:106` declares `assets/audio/` as a directory glob, so adding/removing files inside it does not require a `pubspec.yaml` change. The plan's note matches reality.
- Tests: `packages/mind_audio/test/mind_audio_test.dart` is an empty `void main()` and there are no tests under `packages/breath_module/test/`; no test fixture will go stale from these edits. ✅

## Critical Issues
None.

## Minor Notes
- **Dartdoc update for `AssetAudioCatalog`** — the plan asks for a simpler description but does not pin exact wording. The current dartdoc (lines 13–19) mentions `rootBundle`, `.meta.json`, `loop_end_ms`, `ClippingAudioSource`, OGG, and encoder delay. The implementer should make sure every one of those phrases is gone, not just the most prominent ones; leaving e.g. a stray "rootBundle" reference would leak the old implementation model. Worth restating in the implementation: rewrite the doc, do not patch it.
- **Dartdoc update for `AudioTrack`** — same observation. The current doc on `audio_track.dart` (lines 3–9) and the `loopEnd` field doc (lines 13–18) both reference `ClippingAudioSource`, OGG, encoder delay, and WAV loops. The plan calls for "rewrite", which is the right approach; a partial edit would risk leaving stale terminology.
- **`AudioCatalog` abstract dartdoc** — line 8 reads "Builds a `just_audio` [AudioSource] from an [AudioTrack]." which is already format-neutral. The plan correctly says "Leave the `AudioCatalog` abstract class and its dartdoc unchanged." ✅
- **Commit guidance** — Task 1 has no listed dependencies, Task 2 depends on Task 1, Task 3 depends on Task 2. The "single commit at the end" note is reasonable given the small surface area and that the three tasks together form one atomic behavior change (loop assets + workaround removal must land together to avoid a moment where the FLAC files pass through stale `.meta.json`-aware logic — which would still work in practice because the sidecar lookup just falls through to the plain `AudioSource.asset` branch when no meta is present, but the cleaner sequence is to land them together).

## Positive Notes
- The plan explicitly reconciles the milestone-vs-code mismatch (`.wav` in the roadmap blurb vs. `.opus` in the live code) up front; this prevents an implementer from blindly copy-pasting the milestone wording.
- The plan verifies that all call sites already use positional `AudioTrack(path)`, saving an implementer from a multi-file refactor that would otherwise be required to drop a named parameter.
- Scope is sharply bounded: three files, no asset bundling change, no test changes, no consumer updates. The dependency chain between tasks is correctly identified.
- Task 1's "Do not touch `_tickAssets`" guardrail is exactly the kind of mistake-prevention worth keeping in a focused plan.

PLAN_REVIEW_PASS
