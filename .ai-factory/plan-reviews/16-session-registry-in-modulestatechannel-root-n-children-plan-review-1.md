## Code Review Summary

**Files Reviewed:** plan + 6 code files (`SessionRegistry.dart`, `ModuleStateChannel.dart`, `ModuleSession.dart`, `ActivityType.dart`, `ModuleState.dart`, generated proto), 2 test files, specs (note 14 impl, note 22 contract), ROADMAP line
**Risk Level:** 🟡 Medium

The plan is well-grounded: line references are accurate, the proto surface it relies on exists (`StateEvent.activityType` = field 4, `_mapActivityTypeFromProto` present with the `unused_element` ignore), the additive approach genuinely preserves the legacy `ModuleState`/`ModuleStateEvent` surface, and the test targeting matches the test-philosophy discriminator (silent routing failures). No migrations are needed — the registry is pure in-memory state. One blocking API gap and two divergence/assumption gaps below.

### Context Gates

- **Architecture (WARN → pass):** `ARCHITECTURE.md` present. `SessionRegistry`/`ModuleSession` stay pure Dart (no Flutter/Riverpod), consistent with the domain-layer boundary. No violation.
- **Rules (pass):** `RULES.md` rules target Module Services / App.dart wiring — not this transport layer. The "dependencies injected via constructor" rule is respected (`ModuleStateChannel` owns the registry it constructs; no external stream-wiring). No conflict.
- **Roadmap (pass):** Plan heading matches ROADMAP.md line 53 ("Session registry in `ModuleStateChannel` (root + N children)"), governed by `notes/14-rootchild-session-registry.md`, which depends on the note-22 contract milestone (line 52, `[x]`). Linkage is correct. Note: the spec's `Spec:` tag points at `.ai-factory/notes/14-...` (older `notes/` location), not `.ai-factory/specs/` — resolved fine, no action needed.
- **Skill-context:** `.ai-factory/skill-context/aif-review/SKILL.md` absent — no project overrides to apply.

### Critical Issues

**1. (Blocking) `SessionRegistry` has no way to bulk-clear — Task 2/Task 3 are unimplementable as written.**
Task 2 requires "clear all registry entries" in two places (`_reset()` logout path, and the `no_active_session` reset at `:94-96`), and Task 3 asserts logout → `channel.rootId == null`. But the surface defined in Task 1 (and in the note-22 skeleton) exposes only `upsert`, `removeTerminal(String id)`, `rootId`, `childOfType`, `changes`, `rootIdChanges`, `dispose`. There is **no `clear()` and no key enumeration** — the `_sessions` map is private to the registry, and `removeTerminal` is per-id, so the channel physically cannot empty the registry. `dispose()` closes the subjects, so it cannot be reused for a reset either (and `_registry` is `final`).
Fix: Task 1 must add a public `void clear()` to `SessionRegistry.dart` that empties `_sessions` and fires the change/rootId notifications (guarded against post-`dispose`), and Task 2 must call `_registry.clear()` at those reset points. This edit lands in `SessionRegistry.dart`, which is only in Task 1's file list — so Task 1's scope needs to explicitly include it. Consider adding a small RED/GREEN test for `clear()` since the existing note-22 suite does not cover it.

### Issues / Warnings

**2. (Medium) State/registry divergence on `ACTIVITY_STATUS_UNSPECIFIED`.**
The plan (Task 2) says: on UNSPECIFIED "leave the registry untouched (no id to route)" — but the existing branch (`:155-157`) *does* reset `_state` to `initial()`. So after an UNSPECIFIED frame the single-state is `idle` while the registry may still hold stale entries (`rootId != null`). The spec (note 14 Verify) is silent on UNSPECIFIED, and this is a representation-only milestone, but the divergence is a latent correctness trap for the Phase 62+ consumers that will read the registry. Decide explicitly: either clear the registry here too (matching the single-state reset — likely the intended parity), or document why the divergence is acceptable. Right now the plan asserts "no id to route" as the rationale, but the frame can carry a `moduleSessionId`, so that rationale is not quite accurate.

**3. (WARN) Unstated dependency: every `ACTIVE`/`RESUMED` frame must carry a populated `activity_type`.**
`proto.ActivityType` defaults to `ACTIVITY_TYPE_UNSPECIFIED = 0` when unset, which `_mapActivityTypeFromProto` maps to `null` → the plan then "skips the registry upsert." So if the server ever emits an ACTIVE/RESUMED frame without `activity_type` set, the single-state goes active but the registry stays silently empty (`rootId == null` for a live root) — exactly the silent-failure class this milestone exists to prevent. This is fine *if* the server (note 13) guarantees `activity_type` on every state frame, but the plan should state that assumption explicitly since it is load-bearing (reconnect rebuild is note 20, so nothing else backfills the registry). Two side notes: (a) each skipped frame calls `logPrint('dropping unknown activity type')`, which will fire per-frame and conflicts with the plan's "Logging: minimal" setting — verify this only triggers on genuinely-unknown types, not on every legitimate frame; (b) Task 3 should add a characterization confirming a normal breath `ACTIVE` frame *does* populate the registry, to catch a regression where the server stops sending `activity_type`.

### Positive Notes

- Line references throughout are accurate (`:22-23` subjects, `:125-161` handler, `:90` DISCONNECTED early-return, `:94-96` no_active_session, `:166` start guard, `:224-237` proto mapper, `:239-243` `_reset`, `:247-253` `dispose`) — the plan was written against the real file.
- Correctly scopes the milestone as purely additive and explicitly forbids touching the `start()` single-session guard / `_isPendingStart` (deferred to note 19) — this prevents accidental behaviour drift and keeps the legacy surface byte-identical.
- The terminal-removal semantics are right: `removeTerminal(id)` removes only that entry, and the plan calls out that a child COMPLETED must not drop the root (separate entry) — matching note-22's `remove-only-child` tests.
- `rootIdChanges` design (BehaviorSubject.seeded(null) + `.distinct()` for change-only emission with late-subscriber replay) and the post-`dispose` notify guard are the correct RxDart patterns and mirror existing usage.
- Test plan targets the silent surfaces (registry population, remove-only-child, upsert-in-place `isPaused`, logout clears) and preserves the legacy-event characterization — well aligned with the project's "test only silently-failing logic" philosophy.
