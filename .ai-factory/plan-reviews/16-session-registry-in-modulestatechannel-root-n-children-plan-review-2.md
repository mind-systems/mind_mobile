## Code Review Summary

**Files Reviewed:** plan (v2) + 6 code files (`SessionRegistry.dart`, `ModuleStateChannel.dart`, `ModuleSession.dart`, `ActivityType.dart`, `ModuleState.dart`, generated `module_state.pb.dart`), 2 test files (`session_registry_test.dart`, `module_state_channel_test.dart`), specs (note 14 impl, note 22 contract), ROADMAP lines 52–53, plan-review-1
**Risk Level:** 🟢 Low

This is the second pass. Plan-review-1 raised one blocking gap and two divergence/assumption gaps; the revised plan addresses all three cleanly (see "Resolution of plan-review-1" below). Every line reference re-checked against the current files still holds. The additive contract is preserved: the legacy `_state`/`_events` surface is explicitly untouched, and the registry-upsert path is skipped for any frame whose `activity_type` maps to `null`, so existing single-session tests keep passing. No migrations needed — the registry is pure in-memory state.

### Context Gates

- **Architecture (pass):** `ARCHITECTURE.md` present. `SessionRegistry`/`ModuleSession` stay pure Dart (no Flutter/Riverpod), and the plan reaffirms this ("Keep the class pure Dart"). `ModuleStateChannel` owns the registry it constructs — no cross-boundary stream wiring. Consistent with the transport/domain boundary. No violation.
- **Rules (pass):** `RULES.md` present; its rules target Module Services / `App.dart` wiring, not this transport layer. The constructor-DI rule is respected (the channel constructs and owns `_registry`). No conflict.
- **Roadmap (pass):** Plan heading matches ROADMAP.md line 53 ("Session registry in `ModuleStateChannel` (root + N children)"), governed by `.ai-factory/notes/14-rootchild-session-registry.md`; the note-22 contract milestone it builds on is `[x]` at line 52. Linkage is correct and complete.
- **Skill-context:** `.ai-factory/skill-context/aif-review/SKILL.md` absent — no project overrides to apply.

### Resolution of plan-review-1

- **Finding 1 (blocking — no bulk-clear):** Resolved. Task 1 now adds a public `void clear()` to `SessionRegistry.dart` (empties `_sessions`, fires notifications, post-`dispose` guarded, `.distinct()` absorbs a redundant `null`→`null`), explicitly scoped into Task 1's single file, with a dedicated GREEN test. Task 2 calls `_registry.clear()` at the logout (`_reset`, `:239-243`) and `no_active_session` (`:94-96`) reset points, and Task 3 asserts logout → `rootId == null`.
- **Finding 2 (UNSPECIFIED divergence):** Resolved with the parity choice. Task 2 now calls `_registry.clear()` on `ACTIVITY_STATUS_UNSPECIFIED` (`:155-157`) so the single-state idle reset and the registry never diverge, and it correctly refutes the old "no id to route" rationale (an UNSPECIFIED frame can still carry a `moduleSessionId`). Task 3 adds the parity assertion (idle **and** `rootId == null`).
- **Finding 3 (load-bearing `activity_type` assumption):** Resolved. Task 2 records the assumption as a required code comment and explains why it is load-bearing (reconnect rebuild is note 20; nothing else backfills here). The per-frame `logPrint` concern is addressed (fires only on a genuinely unknown/unset type, an anomaly), and Task 3 adds a positive characterization that a normal `ACTIVE` frame *with* `activity_type` populates the registry — a loud regression guard if the server ever drops the field.

### Critical Issues

None. The plan is implementable as written.

### Minor Observations (non-blocking — no plan change required)

- **Test helper lacks an `activityType` parameter.** The existing `_sessionStateResponse(...)` / `_activateSession(...)` helpers in `module_state_channel_test.dart` construct `proto.StateEvent` without `activityType`. The Task 3 registry tests need frames carrying `activityType` (ROOT / BREATH), so the implementer must either extend the helper with an `activityType` arg or build those frames inline. The plan already states the frames must each carry `activity_type`, so this is just an implementation detail — flagged so it is not overlooked.
- **Change-stream behaviour is not directly asserted.** Task 3 verifies the getters (`rootId`, `childOfType`) but not `changes` / `rootIdChanges` emissions. That is defensible — Phase 62+ consumers of those streams are not wired yet, and the note-22 contract suite is also getter-based — but the streams are themselves a silent-failure surface for later phases. Consider one small assertion that `rootIdChanges` emits on a root upsert/removal; optional.
- **An empty-registry `clear()` still fires the `changes` ping** (only `rootIdChanges` is de-duped via `.distinct()`). Since `clear()` runs on logout / `no_active_session` / UNSPECIFIED, it may fire on an already-empty registry. This is harmless (an idempotent "re-read" ping for adapters/bio) and matches the plan's stated design; noted only for awareness.

### Positive Notes

- All line references re-verified against the live files and accurate: `_state`/`_events` at `:22-23`, `_processProtoEvent` `:125-161`, DISCONNECTED early-return `:90`, `no_active_session` `:94-96`, event emissions `:132-157`, `_mapActivityTypeFromProto` `:224-237` (with the `unused_element` ignore at `:224`), `_reset` `:239-243`, `dispose` `:247-253`, `start()` guard `:166`.
- `proto.StateEvent.activityType` exists as field 4 (confirmed in generated `module_state.pb.dart`) with the ROOT/BREATH/MEDITATION discriminator documented — the surface the plan relies on is real.
- Milestone scope is correctly kept purely additive and explicitly forbids touching the `start()` single-session guard / `_isPendingStart` (deferred to note 19), keeping the legacy surface byte-identical.
- Terminal-removal semantics are right (`removeTerminal(id)` removes only that id; a child terminal must not drop the root) and match the note-22 `remove-only-child` tests already in `session_registry_test.dart`.
- `rootIdChanges` design (`BehaviorSubject<String?>.seeded(null)` + per-subscription `.distinct()` for change-only emission with late-subscriber replay) and the post-`dispose` notify guard are the correct RxDart patterns and mirror existing `ModuleStateChannel` usage.
- Test targeting follows the project's "test only silently-failing logic" discriminator: registry population, remove-only-child, upsert-in-place `isPaused`, UNSPECIFIED/logout clears, and the legacy `ModuleStateEvent` characterization — while explicitly skipping loud surfaces (proto decode, enum mapping).

PLAN_REVIEW_PASS
