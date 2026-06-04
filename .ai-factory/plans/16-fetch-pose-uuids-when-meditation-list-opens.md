# Plan: Fetch pose UUIDs when meditation list opens

## Context
Populate `App.shared.meditationPoseUuids` (slug → UUID) by fetching poses from the backend the moment the meditation list screen opens, so a recorded session can be linked to its server-side pose UUID. The static pose list keeps rendering instantly; the fetch is fire-and-forget with silent (but logged) error handling.

Roadmap milestone: `.ai-factory/ROADMAP.md` line 59 — "Fetch pose UUIDs when meditation list opens". Direct follow-up to the previous milestone (`MeditationPosesGrpcApi` + `App.meditationPoseUuids` cache, commit 79fdab6), which created the `meditationPosesApi` field and `meditationPoseUuids` map this plan populates.

## Settings
- Testing: no
- Logging: minimal — one `debugPrint` in the fetch's catch block
- Docs: no

## Tasks

### Phase 1: Implement fetch-on-open

- [x] **Task 1: Add `refresh()` to the service interface**
  Files: `packages/meditation_module/lib/src/MeditationList/IMeditationListService.dart`
  Add a new method `Future<void> refresh();` to the `IMeditationListService` abstract class, alongside the existing `List<MeditationPoseDTO> poses();`. The method stays declared on the package interface so the concrete implementation in `lib/` can reach `App.shared` without leaking domain knowledge into the package. The interface is re-exported from the `meditation_module.dart` barrel, so the change is visible to the concrete service automatically.

- [x] **Task 2: Implement `refresh()` in the concrete service** (depends on Task 1)
  Files: `lib/MeditationModule/MeditationListService.dart`
  Override `refresh()` as an `async` method. Call `App.shared.meditationPosesApi.listPoses()` (returns `Future<List<({String id, String slug})>>`), then assign `App.shared.meditationPoseUuids = { for (final p in poses) p.slug: p.id }`. Wrap the call in `try { ... } catch (e) { ... }`:
    - On success the cache is replaced with the fresh slug→UUID map.
    - On failure the cache is left as-is (empty), the channel falls back to slug, and there is **no user-visible error** and no rethrow.
    - Inside the catch, emit a single diagnostic line — `debugPrint('MeditationListService.refresh failed: $e');` — so a silent network failure (whose only symptom is "session not recorded server-side") is diagnosable. Referencing `e` in the log also avoids an `unused_local_variable` lint.
  Add imports: `package:mind/Core/App.dart` (matches the form used in `lib/MeditationModule/MeditationModule.dart:4`) and `package:flutter/foundation.dart` for `debugPrint`.

- [x] **Task 3: Fire-and-forget `refresh()` from the ViewModel** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationList/MeditationListViewModel.dart`
  In `build()`, construct the state into a local variable, call `unawaited(service.refresh());`, then return the local:
    ```dart
    @override
    MeditationListState build() {
      final state = MeditationListState(poses: service.poses());
      // Fire-and-forget: assumes build() runs once per screen open (no ref.watch here).
      // If a reactive dependency is ever added to build(), this would re-fire on every rebuild.
      unawaited(service.refresh());
      return state;
    }
    ```
  Add `import 'dart:async';` for `unawaited`. Do **not** introduce any loading state — the static list must still render immediately. The inline comment flags the single-build assumption for future maintainers (`build()` currently has no `watch` calls, so it runs once per screen construction).

## Notes
- Spec reference: `.ai-factory/notes/86-meditation-poses-list-fetch.md`
- Tasks 2 and 3 both depend only on Task 1 and are independent of each other — they can proceed in parallel once the interface lands.
- Single logical change; commit once after all three tasks: "Fetch meditation pose UUIDs when list screen opens".
