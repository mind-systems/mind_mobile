# Code Review: Route module-package logs through `mind_logger`

**Scope:** `git diff HEAD` — pubspec dependency wiring across 5 module packages + migration of 3 stray `debugPrint`s to `logPrint`.

## What was changed

- `mind_logger` path dep added to `breath_module`, `mind_audio`, `bci_module`, `meditation_module`, `mind_ui` pubspecs (alphabetically ordered; `meditation_module` reordered `mind_ui`/`mind_l10n` to keep order — cosmetic, harmless).
- `BreathSessionStateMachine.dart:358,388` — `debugPrint` → `logPrint`; `mind_logger` import added; `flutter/foundation.dart` retained (still needed for `kDebugMode` at 357/387).
- `audio_one_shot.dart:44` — `debugPrint` → `logPrint`; `mind_logger` import added; `flutter/foundation.dart` removed.
- `breath_module`/`mind_ui` `pubspec.lock` updated with `mind_logger` (direct) + `observe`/`http` (transitive).

## Verification performed

- **Message strings unchanged** — both `[SM] transition: …` calls and the `[AudioOneShot] play failed: …` string are byte-for-byte identical pre/post. ✅
- **No log lines added/removed** — 1:1 sink swap. ✅
- **Import correctness** — `package:mind_logger/mind_logger.dart` re-exports `logPrint` (`mind_logger.dart` → `src/logger.dart`); signature `logPrint(Object?)` accepts the existing interpolated-string args. ✅
- **`foundation.dart` retention logic** — kept in `BreathSessionStateMachine` (`kDebugMode` still used), removed from `audio_one_shot` (no remaining foundation symbol). ✅
- **`flutter analyze`** — `mind_audio` and `breath_module` both report "No issues found!" — confirms the `audio_one_shot` import removal left no dangling reference and no unused import was introduced. ✅
- **Stray-log grep guard** — `debugPrint(` / `dart:developer` over `packages/*/lib` (excl. generated + the facade's own `logger.dart`) returns nothing. ✅
- **No circular dependency** — `mind_logger` depends only on `flutter` + `observe` (git); none of the 5 target packages are reachable from it. ✅

## Observations (non-blocking, no action required)

1. **Release-time behavior change in `audio_one_shot.dart` (intended).** The migrated `logPrint` at line 44 is *not* wrapped in `if (kDebugMode)` (the original `debugPrint` wasn't either). Per the facade, in release builds (`LOG_DESTINATION` default `file`) `logToObserver` is true, so this play-failure error will now reach the observer/file sink instead of being a console-only no-op. This is precisely the milestone's goal (routing module logs to Loki), so it is correct and expected — noted only because it is a real release-time logging change, not a pure no-op swap. The `[SM]` transition logs remain `kDebugMode`-guarded, so their release behavior is unchanged.

2. **`pubspec.lock` coverage.** Only `breath_module` and `mind_ui` have committed lock files in the diff; `mind_audio`/`bci_module`/`meditation_module` do not track `pubspec.lock` (typical for leaf library packages). Not a problem — the lock is regenerated on `pub get`.

## Conclusion

The implementation matches the plan exactly, all stated guards hold (strings unchanged, no log lines added/removed, grep clean, analyze clean), and no correctness, security, or runtime-breakage issues were found.

REVIEW_PASS
