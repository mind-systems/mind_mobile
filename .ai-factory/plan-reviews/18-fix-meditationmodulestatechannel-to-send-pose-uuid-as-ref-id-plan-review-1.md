# Plan Review: Fix MeditationModuleStateChannel to send pose UUID as ref_id

**Plan:** `.ai-factory/plans/18-fix-meditationmodulestatechannel-to-send-pose-uuid-as-ref-id.md`
**Risk Level:** 🟢 Low

## Verification against the codebase

Every factual claim in the plan was checked against the current source:

- **Channel param/field names** — `lib/MeditationModule/Core/MeditationModuleStateChannel.dart:10,16,21` confirm `final String _poseId;`, the `required String poseId` constructor param, and the `_poseId = poseId` initializer. The rename `poseId → refId` / `_poseId → _refId` is accurate.
- **Internal UUID lookup** — line 30 is exactly `final refId = App.shared.meditationPoseUuids[_poseId] ?? _poseId;`, and line 31 calls `_channel.start(type: ActivityType.meditation, refId: refId);`. Removing the lookup and passing `_refId` directly is correct.
- **`start()` signature** — `lib/Core/Grpc/ModuleStateChannel.dart:151` is `void start({required ActivityType type, String? refId})`. The proposed call `start(type: ActivityType.meditation, refId: _refId)` matches.
- **Unused `App` import** — within the channel file, `App` is referenced *only* at line 30. After the lookup is removed, the `package:mind/Core/App.dart` import (line 3) becomes dead. The plan's conditional phrasing ("drop … if nothing else references `App`") is safe and correct — nothing else does.
- **`buildSession` site** — `lib/MeditationModule/MeditationModule.dart:23-39` confirms `buildSession(context, {required String poseId})`, the `MeditationModuleStateChannel(... poseId: poseId)` call at lines 29-33, and `MeditationSessionViewModel(poseId: poseId)` at line 28. The plan correctly leaves the ViewModel slug-based and only swaps the channel argument.
- **`App` import stays in MeditationModule.dart** — that file still uses `App.shared.moduleStateChannel` (line 30), so its `App` import must remain. The plan does not touch it. Correct.
- **`meditationPoseUuids` shape** — `lib/Core/App.dart:100` is a mutable `Map<String, String>` (slug → UUID). The `[poseId] ?? poseId` fallback expression is valid and matches existing usage in `MeditationListService` and `MeditationNoteService`.
- **No other callers** — `MeditationModuleStateChannel(` is constructed only in `buildSession`. No tests reference it (Settings: Testing = no). The rename has a single call site to update, which the plan covers.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — PASS. Moving slug→UUID resolution out of the plumbing channel and into the module assembly point (`buildSession`) is consistent with the layered model: the channel becomes pure wire transport holding "whatever string is sent," and domain/DTO resolution lives at the wiring layer.
- **Rules (`.ai-factory/RULES.md`)** — PASS. No new state, stream, or trigger is added to `App.dart` (only an existing field is read). The channel continues to receive its dependency (`refId`) via constructor injection, satisfying the constructor-injection rule.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — PASS. Maps 1:1 to the open Phase 33 milestone at line 63 ("Fix `MeditationModuleStateChannel` to send pose UUID as `ref_id`"), including the same two-change decomposition and the `final refId = App.shared.meditationPoseUuids[poseId] ?? poseId` expression. Spec note `.ai-factory/notes/87-meditation-channel-uuid-fix.md` agrees.

## Observations (non-blocking)

- **WARN — resolution timing shifts earlier.** Currently the UUID is resolved lazily inside `_onState` at session-*active* time; the plan resolves it eagerly at `buildSession()` (screen-build time). Both occur after the meditation list screen has fired its fire-and-forget `refresh()`, and milestone "Persist meditation poses to Drift" (ROADMAP line 61) now pre-populates the cache at cold start, so in practice the map is already filled by either point. The earlier resolution is therefore equivalent in the normal case and the documented slug fallback (server-reject, no new crash) is unchanged. No action needed — noted only so QA understands the moved resolution point.
- **FYI — Phase 33 Notes follow-ups.** Later milestones (ROADMAP lines 71, 77, 79) add `moduleSessionId` capture and a `MeditationSessionCoordinator` wired through `buildSession()`. They will edit the same two files but are out of scope here; this plan does not conflict with them.

## Conclusion

The plan is accurate, minimal, and self-consistent. File paths, field/param names, the `start()` API, and the unused-import cleanup all match the live code. Both context gates and the roadmap linkage pass.

PLAN_REVIEW_PASS
