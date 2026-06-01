# Plan: Remove leftover `[Sound]` debug instrumentation

## Context
Strip the throwaway `_ts()` timestamp helper and all `[Sound]` `debugPrint` lines from `BreathSoundCoordinator` — the same class of debug instrumentation Phase 16 already removed (`[BREATH-PROBE]`). No behavior change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Cleanup

- [x] **Task 1: Remove `_ts()` helper and all `[Sound]` debug logs**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Delete:
  - The top-level `String _ts() { ... }` function (lines 9–13).
  - Every `if (kDebugMode) debugPrint('${_ts()} [Sound] ...')` line:
    - In `initialize`: `[Sound] initialize start`.
    - In `_initAudio`: `[Sound] initialize ready — listeners attached`.
    - In `_onStateChanged` (status branch): `[Sound] status: ...` and `[Sound] status→breath crossfadeTo ...`.
    - In `_onStateChanged` (phase branch): `[Sound] phase: ...` and `[Sound] phase change crossfadeTo ...`.
    - In `_onTick`: `[Sound] _onTick ...`.
  Keep the `import 'package:flutter/foundation.dart';` line — still required for `ValueNotifier` (and `kDebugMode` is no longer referenced, but the import stays for `ValueNotifier`). Verify no other use of `kDebugMode`/`debugPrint` remains; if none, the import is still valid for `ValueNotifier`. Make no other edits — pure deletion, no logic or whitespace-structure changes beyond removing the deleted lines.
