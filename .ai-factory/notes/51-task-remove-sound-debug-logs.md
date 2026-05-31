# Task Spec — Remove leftover `[Sound]` debug instrumentation

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 42 Task 6 (note 35 Area A)

## Current state
`packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` still carries the `_ts()` timestamp helper and multiple `if (kDebugMode) debugPrint('${_ts()} [Sound] ...')` lines across `initialize`, `_onStateChanged`, and `_onTick` — the same throwaway instrumentation Phase 16 already stripped as `[BREATH-PROBE]`.

## Target
- Delete the top-level `_ts()` function and every `[Sound]` `debugPrint` line.
- Keep the `package:flutter/foundation.dart` import (still needed for `ValueNotifier`).
- No behavior change.

## Files
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` (one file).
