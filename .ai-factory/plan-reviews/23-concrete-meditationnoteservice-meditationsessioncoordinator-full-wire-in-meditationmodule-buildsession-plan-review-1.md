# Plan Review: Concrete `MeditationNoteService` + `MeditationSessionCoordinator` + wire in `MeditationModule.buildSession()`

**Plan:** `.ai-factory/plans/23-concrete-meditationnoteservice-meditationsessioncoordinator-full-wire-in-meditationmodule-buildsession.md`
**Risk Level:** 🟢 Low — plan is accurate, well-scoped, and matches the codebase. No blocking issues.

## Verification of plan assumptions

Every concrete claim in the plan was checked against the codebase and holds:

| Assumption | Verified |
|---|---|
| `MeditationNoteRepository.save(String poseId, String text, {String? serverSessionId})` exists with that signature | ✅ `lib/MeditationModule/MeditationNoteRepository.dart:10` |
| `App.shared.meditationNoteRepository` exists | ✅ `lib/Core/App.dart:101`, initialized line 244 |
| `App.shared.meditationPoseUuids` (slug→UUID map) exists | ✅ `lib/Core/App.dart:102` |
| `MeditationNoteScreen` is exported from `meditation_module.dart` | ✅ barrel line 12 — package import works as written; no `src` fallback needed |
| `MeditationModuleStateChannel.moduleSessionId` getter exists | ✅ `Core/MeditationModuleStateChannel.dart:32` |
| Screen calls `onSessionStopped()` with no args on `active → idle` | ✅ `MeditationSessionScreen.dart:32-42` |
| `IMeditationSessionCoordinator` + `meditationSessionCoordinatorProvider` exist | ✅ package `IMeditationSessionCoordinator.dart` |
| Note screen returns `String` (OK) / `null` (Cancel) via `pop` | ✅ `MeditationNoteScreen.dart:57,62` |
| `buildSession(context, {required poseId})` shape + `late final stateChannel` pattern | ✅ `MeditationModule.dart:24-44` |
| `App` already imported in `MeditationModule.dart` | ✅ line 4 |
| Slug→UUID resolution `App.shared.meditationPoseUuids[slug] ?? slug` matches spec | ✅ note `88-meditation-notes-pose-id-rename.md:39` |

The lazy-closure reasoning is correct: `getSessionId: () => stateChannel.moduleSessionId` captures the `late final stateChannel` that is assigned inside the `meditationSessionViewModelProvider` override closure (runs on first screen build). `onSessionStopped` only fires after `active → idle`, which requires the screen to have built and started — so `stateChannel` is always assigned by the time the closure is invoked. No `LateInitializationError` risk.

## Context Gates

**Architecture (`ARCHITECTURE.md`):** ✅ Aligned. The interface-in-`lib/` placement is acceptable here — `IMeditationNoteService` is consumed only by the coordinator (also in `lib/`) and never crosses the package boundary, so it does not need to live inside `packages/meditation_module/`. `MeditationNoteService` stays stateless (two final fields), consistent with the service conventions.

**Rules (`RULES.md`):** ✅ No violations.
- Rule 7 (module Services must be stateless): satisfied — no streams/subscriptions/`dispose()`.
- Rule 8 (no module state added to `App.dart`): satisfied — the plan adds nothing to `App.dart`; `meditationNoteRepository` / `meditationPoseUuids` were added in prior milestones.

**Roadmap (`ROADMAP.md`):** ⚠️ WARN — minor scope overlap. The plan implements `getSessionId` now, but the *next* roadmap milestone ("Wire gRPC note sync") explicitly lists "Add `String? Function() getSessionId` to `MeditationSessionCoordinator`; pass `getSessionId: () => stateChannel.moduleSessionId`". Pulling it forward is sensible (the local `serverSessionId` write needs it), but be aware the next milestone's description will partly be already done. Non-blocking — update the next milestone when you reach it.

## Findings (all non-blocking)

### 1. Fire-and-forget error handling (robustness — recommend addressing)
`unawaited(noteService.saveNote(...))` does **not** swallow errors — if `_repository.save` throws (Drift write failure), the rejected future surfaces as an uncaught async error in the zone. Settings request "minimal" logging, yet no task adds any error handling on the local save path (the gRPC `catch` only arrives in the next milestone). Recommend wrapping the body of `MeditationNoteService.saveNote` in a `try/catch` with a `debugPrint`, mirroring `MeditationListService.refresh` (`MeditationListService.dart:19-21`). This also satisfies the "minimal logging" setting.

### 2. Navigation convention divergence (minor, justified)
The coordinator uses raw `Navigator.of(context).push(MaterialPageRoute(...))`, whereas the sibling `BreathSessionCoordinator` navigates via GoRouter (`context.push(path)`). This is justified — `MeditationNoteScreen` is **not** a registered GoRouter route (absent from `router.dart`) and a value-returning modal is cleaner with an imperative push. Cancel/OK both `pop`, so the imperatively pushed route unwinds correctly. The `if (!context.mounted) return;` guard matches the established `BreathSessionCoordinator` pattern (`BreathSessionCoordinator.dart:24,30`). No change required — noted for consistency awareness.

### 3. UUID fallback may persist a slug (inherent to spec — add a comment)
`meditationPoseUuids` is populated lazily when the meditation list opens (`App.dart:102`), with a cached copy loaded at init (`App.dart:245`). If neither has populated the map, `?? poseSlug` stores the **slug** in the `poseId` column instead of the server's expected UUID. This is by design per note 88, and the init-time cache mitigates it in practice, but it's a silent data-shape mismatch worth a one-line comment at the fallback site so the next-milestone gRPC sync author knows a slug can leak through.

## Positive Notes
- Plan correctly identifies that the screen calls `onSessionStopped()` argument-less and routes the session-id need through a constructor-injected getter rather than changing the interface — clean.
- Correctly preserves the `late final stateChannel` lazy-resolution and explains why capture-before-assignment is safe.
- Empty/whitespace handling (`text?.trim() ?? ''`, Cancel→`null`, empty-OK→`''`) is precise and matches the screen's actual `pop` contract.
- Slug-in-constructor decision keeps `buildSession` consistent with how `poseId` is already threaded to the VM and asset path — matches note 88's stated rationale.
- Dependency ordering across the four tasks is correct and minimal.

The plan is solid and implementable as written; the three findings are optional refinements.

PLAN_REVIEW_PASS
