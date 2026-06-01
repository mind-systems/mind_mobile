# Code Review: Remove leftover `[Sound]` debug instrumentation (105)

**Scope reviewed:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` (only code file changed; the `.ai-factory/` files are plan artifacts).

## Findings

### 1. [HIGH] Two dangling `prev` local variables left behind — `flutter analyze` now fails

The deleted `[Sound]` debug lines were the **only consumers** of two local variables that were not removed:

- `_onStateChanged`, status branch — line 171:
  ```dart
  final prev = _currentStatus;   // <-- only used by the deleted debugPrint
  _currentStatus = state.status;
  ```
- `_onStateChanged`, phase branch — line 199:
  ```dart
  final prev = _currentPhase;    // <-- only used by the deleted debugPrint
  _currentPhase = state.phase;
  ```

`flutter analyze` confirms two `unused_local_variable` warnings:

```
warning • The value of the local variable 'prev' isn't used • ...BreathSoundCoordinator.dart:171:13 • unused_local_variable
warning • The value of the local variable 'prev' isn't used • ...BreathSoundCoordinator.dart:199:13 • unused_local_variable
2 issues found.
```

`unused_local_variable` is **warning** severity. `flutter analyze` exits non-zero on warnings, so this breaks the analyze/CI gate. The plan called for a pure no-behavior-change cleanup; leaving dead variables behind is an incomplete deletion.

**Fix:** delete both `final prev = ...;` lines, keeping the assignment that follows:
```dart
// status branch
_currentStatus = state.status;
```
```dart
// phase branch
_currentPhase = state.phase;
```

## Confirmed correct

- `_ts()` helper fully removed; no remaining references.
- All six `[Sound]` `debugPrint` lines removed; no `[Sound]` strings or `_ts(` calls remain.
- `import 'package:flutter/foundation.dart';` correctly retained — still required for `ValueNotifier` (line 25). `kDebugMode`/`debugPrint` are no longer referenced anywhere in the file, but the import is still needed, so no unused-import warning.
- No behavior change in audio logic, fade computation, or tick gating.

---

Resolve finding #1, then the change is good to merge.
