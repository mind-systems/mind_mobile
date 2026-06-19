# Plan: Route module-package logs through `mind_logger`

## Context
Wire the extracted `mind_logger` facade into the module packages so the CLAUDE.md "all logs through `logPrint`" rule becomes enforceable there, and migrate the 3 stray console-only `debugPrint`s to `logPrint`. This is compliance (changing the log sink), not a logging-policy change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add `mind_logger` path dependency to module packages

- [x] **Task 1: Add `mind_logger` path dep to the two packages with stray logs**
  Files: `packages/breath_module/pubspec.yaml`, `packages/mind_audio/pubspec.yaml`
  Add `mind_logger:` with `path: ../mind_logger` under `dependencies:` in each pubspec, matching the existing path-dep style (e.g. how `breath_module` already declares `mind_audio`/`mind_ui`). `breath_module` already has other path deps — insert alphabetically among them; `mind_audio` currently only depends on `flutter` + `just_audio` — add the new entry there.

- [x] **Task 2: Add `mind_logger` path dep to the zero-log packages for rule-uniformity**
  Files: `packages/bci_module/pubspec.yaml`, `packages/meditation_module/pubspec.yaml`, `packages/mind_ui/pubspec.yaml`
  Add the same `mind_logger:` `path: ../mind_logger` entry under `dependencies:` in each. These packages have no current logs; this only grants the capability so any future log uses `logPrint`. No code changes in these packages.

- [x] **Task 3: Resolve dependencies** (depends on Task 1, Task 2)
  Files: (none — command only)
  Run `/usr/local/bin/flutter pub get` in each of the 5 modified packages (`breath_module`, `mind_audio`, `bci_module`, `meditation_module`, `mind_ui`) so the new path dep resolves. Confirm no resolution errors.

### Phase 2: Migrate the 3 stray `debugPrint`s to `logPrint`

- [x] **Task 4: Migrate `BreathSessionStateMachine` transition logs** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
  Add `import 'package:mind_logger/mind_logger.dart';` to the import block. Replace the two `debugPrint('[SM] transition: $reason, exercise: $_exerciseIndex')` calls at lines 357 and 387 with `logPrint(...)`, keeping the message string byte-for-byte identical. **Keep the existing `import 'package:flutter/foundation.dart';`** — it is still required for `kDebugMode` (used in the surrounding `if (kDebugMode)` guards at lines 356/386). Do not touch the guards or add/remove any log lines.

- [x] **Task 5: Migrate `AudioOneShot` play-failure log** (depends on Task 1)
  Files: `packages/mind_audio/lib/src/audio_one_shot.dart`
  Add `import 'package:mind_logger/mind_logger.dart';`. Replace the `debugPrint('[AudioOneShot] play failed: $e  state=${_player.processingState}')` call at line 44 with `logPrint(...)`, message string unchanged. After this change `package:flutter/foundation.dart` has no remaining usage in this file (`debugPrint` was its only consumer) — **remove that import** to keep `flutter analyze` clean. Verify no other foundation symbol is used before removing.

### Phase 3: Verify guards hold

- [x] **Task 6: Verify clean analyze and no remaining stray logs** (depends on Task 4, Task 5)
  Files: (none — verification only)
  Run `/usr/local/bin/flutter analyze` and confirm it is clean (no unused-import or other warnings introduced). Then grep `packages/*/lib` (excluding generated `*.g.dart` / `*.freezed.dart`) for `debugPrint(` and `dart:developer` and confirm it returns nothing except the facade's own implementation in `packages/mind_logger/lib/src/logger.dart` (which is the intended sink and out of scope).
