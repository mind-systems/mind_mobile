# Plan Review: Implement `AudioCatalog` and `AssetAudioCatalog` in `mind_audio`

**Plan:** `.ai-factory/plans/18-implement-audiocatalog-and-assetaudiocatalog-in-mind-audio.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — OK. The `mind_audio` package is explicitly described as a standalone, zero-domain-knowledge module; introducing an abstract `AudioCatalog` plus a concrete `AssetAudioCatalog` keeps the package self-contained. No domain types are referenced.
- **RULES.md** — OK. Rules target Services with stateless observation (`StreamController`/`StreamSubscription`/`dispose`). The catalog is a stateless single-method type — no streams, no DI of mutable collaborators, no lifecycle. Compliant by construction.
- **ROADMAP.md** — OK. The plan implements roadmap line 37 (Phase 13 — mind_audio). Previous tasks (package scaffold, `AudioTrack`) are checked off; this is the logical next task. Subsequent tasks (`AudioLooper`, `AudioOneShot`, `breath_module` wiring) depend on it.

## Codebase Verification

- `packages/mind_audio/lib/src/audio_track.dart` exists with the shape the plan assumes (`AudioTrack(this.assetPath, {this.loopEnd})`). ✅
- `packages/mind_audio/lib/mind_audio.dart` currently contains exactly the single export line the plan expects to append below. ✅
- `packages/mind_audio/pubspec.yaml` already declares `just_audio: ^0.10.5` and `flutter` SDK — both required for `AudioSource`/`ClippingAudioSource` and `rootBundle`. No pubspec change needed. ✅
- Root `pubspec.yaml` declares `assets/audio/` as a directory glob and the three `*.ogg.meta.json` sidecars exist on disk (`ohm_inhale`, `ohm_exhale`, `ohm_hold`), each with `{ "loop_end_ms": 4000.0 }`. The "no pubspec/asset changes" claim is correct. ✅
- Note 08 (`.ai-factory/notes/08-audio-catalog.md`) — the authoritative spec — matches the plan's task description verbatim (class shape, comment text, exception handling, fallback semantics). ✅

## Observations (Non-blocking)

1. **`AudioTrack.loopEnd` is unused by the catalog.** The catalog reads `loop_end_ms` from the sidecar rather than from the track. This is consistent with note 08 (the source of truth) and note 06 leans the same way, but `loopEnd` on `AudioTrack` now serves no purpose in the asset-bundle code path. Not a problem for this task — flag it as a follow-up cleanup once the wider Phase 13 refactor lands, so the field is either removed or repurposed (e.g. as an override that wins over the sidecar).
2. **JSON parsing robustness.** `jsonDecode("4000.0") as num).round()` is safe (`double → int`); if a malformed sidecar contains a string under `loop_end_ms`, the cast throws and is correctly swallowed by `catch (_)`, falling back to the plain source. The plan's behavior is correct here — noting it explicitly so the implementer doesn't accidentally narrow the catch.
3. **Minimal logging setting.** The plan honors "logging: minimal" — no logger calls. Reasonable for production behavior, but a single `debugPrint` inside `catch (_)` would help diagnose sidecar typos during asset authoring. Optional; not required.

## Critical Issues

None.

## Positive Notes

- Plan is correctly scoped: one new file, one barrel-export line, one verification step.
- Required code comment is quoted verbatim with the correct location (inside the `if (loopEndMs != null)` branch), as note 05 mandates.
- Verification step is appropriate: `flutter pub get` + `flutter analyze` from the package directory — no test scaffolding needed for a pure source-construction wrapper.
- Style guidance ("match `audio_track.dart`") is concrete and references an existing reference file.

PLAN_REVIEW_PASS
