# Code Review: Implement `AudioOneShot` in `mind_audio` (plan 21)

**Plan:** `.ai-factory/plans/21-implement-audiooneshot-in-mind-audio.md`
**Files reviewed:**
- `packages/mind_audio/lib/src/audio_one_shot.dart` (new)
- `packages/mind_audio/lib/mind_audio.dart` (export added)

## Scope verification

`git status` / `git diff HEAD` shows only the plan, plan-review, the new `audio_one_shot.dart`, and the one-line export append in `mind_audio.dart`. No unintended changes; no proto/asset/pubspec edits — correctly identified as unnecessary in the plan.

## Plan ↔ code mapping

| Spec item | Implementation | Verdict |
|---|---|---|
| `final AudioPlayer _player = AudioPlayer();` field initializer | `audio_one_shot.dart:9` | ✅ |
| `Future<void> load(AudioSource source) → await _player.setAudioSource(source)` | `audio_one_shot.dart:12-14` | ✅ |
| `void play() → unawaited(_player.seek(Duration.zero).then((_) => _player.play()))` | `audio_one_shot.dart:17-19` | ✅ (verbatim match to `BreathSoundCoordinator.dart:235`) |
| `void stop() → unawaited(_player.stop())` | `audio_one_shot.dart:22-24` | ✅ |
| `void dispose() → unawaited(_player.dispose())` | `audio_one_shot.dart:27-29` | ✅ |
| Imports: `dart:async`, `package:just_audio/just_audio.dart` | `audio_one_shot.dart:1-2` | ✅ |
| Dartdoc on class + each public method | All present | ✅ |
| Barrel export appended after `audio_looper.dart` | `mind_audio.dart:4` | ✅ |

## Correctness checks

- **API name**: `_player.setAudioSource(source)` (singular) is the correct `just_audio` method for a single source — `setAudioSources` (plural) is the playlist variant used by `AudioLooper`. No typo.
- **`unawaited` import**: `dart:async` exports `unawaited`. Used correctly on three fire-and-forget calls.
- **Field initializer + implicit default constructor**: Dart synthesizes the default generative constructor; `_player` is constructed at instance creation time. Matches the plan's explicit reasoning that a `const` constructor is impossible here.
- **`flutter analyze`**: clean — `No issues found!` ran inside `packages/mind_audio`.
- **No domain leakage**: class has no streams, no guards, no asset paths, no `kDebugMode` calls — pure mechanics primitive, exactly as scoped.

## Runtime behavior risks (all known, all accepted)

1. **`play()` before `load()` completes** — `seek` on an empty `AudioPlayer` will throw or no-op depending on `just_audio` platform. The source coordinator shared this exact gap; no regression, caller owns sequencing. Plan-review item #3 already flagged this as a non-blocker.
2. **Any method after `dispose()`** — `_player` is `final` and non-nullable, so post-dispose calls dispatch on a disposed `AudioPlayer` and will throw. Inconsistent with `AudioLooper`'s null-and-discard teardown, but acceptable for a single-field primitive. Plan-review item #4 already flagged as accepted design.
3. **Concurrent `load()` calls** — `setAudioSource` replaces the buffered source; awaited so the contract is "last call wins after its `await` returns". No mutation race.

None of these are bugs introduced by this change.

## Style consistency

- Dartdoc style (one-liner per method, `[name]` cross-refs) matches `AudioLooper` and `AudioTrack`.
- Two-line file separators, import grouping (`dart:` first, then `package:`), and `unawaited` placement all match existing `mind_audio` source files.
- Trailing newline present.

## Security / safety

No I/O surface beyond `just_audio`. No user input, no string interpolation, no platform channel raw access. N/A for OWASP-style concerns.

## Conclusion

The implementation is a faithful 1:1 extraction of the tick-player mechanics from `BreathSoundCoordinator` into a reusable primitive, matches the plan and the architecture note (`.ai-factory/notes/06-mind-audio-architecture.md` § `AudioOneShot`) exactly, compiles clean under `flutter analyze`, and ships no behavior change to existing callers (no consumer wired up yet — that lands in milestones 22 and 23 per the roadmap). Nothing to fix.

REVIEW_PASS
