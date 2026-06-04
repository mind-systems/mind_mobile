# Code Review: Fetch pose UUIDs when meditation list opens

**Plan:** `16-fetch-pose-uuids-when-meditation-list-opens.md`
**Files changed (code):** 3
- `packages/meditation_module/lib/src/MeditationList/IMeditationListService.dart`
- `lib/MeditationModule/MeditationListService.dart`
- `packages/meditation_module/lib/src/MeditationList/MeditationListViewModel.dart`

**Risk Level:** 🟢 Low

## Scope

The diff implements exactly the three planned tasks and nothing else. The remaining staged files are plan/review artifacts (`.ai-factory/...`), not code.

## Correctness Verification

Each change was read in full and checked against its surrounding code:

- ✅ **Interface (`IMeditationListService`)** — `Future<void> refresh();` is a clean additive declaration alongside `List<MeditationPoseDTO> poses();`. Re-exported via the `meditation_module` barrel, so it is visible to both the concrete service and the ViewModel.
- ✅ **Concrete service (`MeditationListService`)** — `refresh()` overrides the new interface member. `App.shared.meditationPosesApi.listPoses()` returns `Future<List<({String id, String slug})>>`; the comprehension `{ for (final p in poses) p.slug: p.id }` produces a `Map<String, String>` matching the field type at `lib/Core/App.dart:100`. The field is non-`final` and mutable, so reassignment is valid.
- ✅ **Imports** — `package:flutter/foundation.dart` (for `debugPrint`) and `package:mind/Core/App.dart` are both genuinely new and required; the path style matches `MeditationModule.dart`. The package `lib/` file importing `package:mind/...` does not violate the module boundary because this is the concrete service that lives in `lib/`, not package code.
- ✅ **ViewModel (`MeditationListViewModel.build()`)** — refactored from an expression body to a block that builds state into a local, fires `unawaited(service.refresh())`, and returns the local. `import 'dart:async';` is added for `unawaited`. `build()` has no `ref.watch` calls, so it runs once per screen construction and `refresh()` fires once per open, as intended.
- ✅ **Wiring** — `MeditationModule.buildSessionList()` injects the concrete `MeditationListService()` into the ViewModel, so the real `refresh()` runs at runtime.

## Runtime Failure Analysis

- **Pre-initialization access:** `App.shared` is `static late App` and `meditationPosesApi` is `late final`. If `refresh()` somehow ran before `App.initialize()`, the resulting `LateInitializationError` (an `Error`, not an `Exception`) is still caught by the bare `catch (e)` and logged — no crash. In practice the meditation list cannot open before app boot completes, so this is purely defensive.
- **Network / gRPC failure:** Caught, logged via `debugPrint`, cache left unchanged (empty `const {}` default). The session channel falls back to slug — the pre-existing safe default. No user-visible error, no rethrow.
- **Race / re-entrancy:** Rapid re-opens could overlap two `refresh()` calls. Both write the same idempotent slug→UUID map (last-write-wins); no corruption, no partial state. Acceptable.
- **Catch breadth:** `catch (e)` intentionally catches all throwables for graceful degradation of a fire-and-forget call — appropriate here.
- **No migrations, no proto changes, no type mismatches, no schema/DTO drift.**

## Findings

None. The implementation is correct, matches the plan, respects the module boundary, and degrades gracefully on failure.

REVIEW_PASS
