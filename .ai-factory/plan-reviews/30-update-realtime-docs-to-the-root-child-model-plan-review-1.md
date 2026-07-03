## Code Review Summary

**Files Reviewed:** 1 plan + 2 target docs + supporting code (`RootStateChannel`, `BiometricStreamClient`, `KeepAliveCoordinator`, `ModuleStateChannel`, ROADMAP/notes)
**Risk Level:** 🟡 Medium

The plan is a documentation-only rewrite (Phase 67, the final milestone in the root/child chain). I verified that the behaviour it describes is actually **shipped and committed** — the entire chain (notes 13–29, commits `55de244` → `cf6c2fb`) is on `main`, so the docs will describe real current state, not aspiration. Line references in the plan (`:78-82`, `:7-22`, `:48-50`, `:52-58`, `:38-40`, `:66-72`, `:84-93`, `:95-107`; meditation `:74`, `:52-72`) all match the current doc content exactly.

Spot-checked behavioural claims — all accurate:
- **Root opened on stream-up, never ended** — `RootStateChannel` sends `startRoot` on `sessionStreamOpened`, has no end/stop/pause/resume path (`RootStateChannel.dart:13,21-24`). ✅
- **Idempotency token reused, never regenerated** — `_clientActivityId` is a single `Uuid().v4()` fixed per instance (`:16`). ✅
- **Bio bound to `root.id`, cleared only when root is gone** — `BiometricStreamClient` sources the id from `rootIdChanges`, clears `_currentSessionId` only on `rootId == null` (`:127-136`), not on child end. ✅
- **Phases stay on the child id** — confirmed separate source (note 17). ✅
- **Last-connect-wins → passive until "use here"** — `takeOverHere()` (`ModuleStateChannel.dart:411`) + `SessionTerminated(movedToAnotherDevice)` (`:289`) + passive-refuses-reopen (`:179`). ✅
- **Pause = client stops emitting phases, server filters nothing** — matches note 17 / spec note §11. ✅

The plan faithfully follows its governing spec (`.ai-factory/notes/21-rootchild-docs-update.md`) and encodes the correct global doc guards (Russian, describe-behaviour-not-code, current-state-only, no FSM/`SessionTerminated`/enum internals).

### Context Gates
- **Architecture** (WARN — none): `ARCHITECTURE.md` has no realtime/root-child section to contradict; no boundary issue.
- **Rules** (WARN — none): `RULES.md` has no doc-specific rule; plan's guards already mirror the global CLAUDE.md doc style.
- **Roadmap** (PASS): milestone matches `ROADMAP.md:106` ("Update realtime docs to the root/child model"), correctly marked as the last task after all behaviour settled. Governing spec note 21 is referenced and consistent.

### Critical Issues

**1. Missing step — `docs/realtime/data-flow.mmd` is not in scope, yet it violates the plan's own guard.**
The doc under rewrite opens by pointing at this sibling diagram (`live-session-tracking.md:5` — "Общая картина потоков — блок-диаграмма [data-flow.mmd]"). The diagram still encodes the retired single-session model verbatim:
- `data-flow.mmd:21` — `Session engine` / **"one active session per user"** · issues correlation key
- `:34-35`, `:46` — the single **"correlation key"** binding all three streams (retired: bio now binds to `root.id`, phases to the child id, analytics time-joins against the root timeline).

The plan's global guard states: *"no remaining reference to 'one active session per user' … nor to server-side pause filtering."* Neither Task 1 nor Task 2 lists `data-flow.mmd` in its `Files:` — both list only the `.md`. As written, the plan leaves a referenced diagram that (a) literally contains the exact phrase the guard forbids, and (b) contradicts the rewritten prose (single correlation key vs. root.id/child.id split). **Add `docs/realtime/data-flow.mmd` to the rewrite scope**: `Session engine` → root + N concurrent children (no "one active session per user"); replace the single "correlation key" edges with bio→`root.id` / phase→child.id bound to the shared root timeline. (Note the `.mmd` node-id pitfalls in the mobile CLAUDE.md if any new nodes are added.)

### Non-blocking Issues

**2. WARN — "preserve keep-alive/foreground service as-is" may perpetuate a stale statement.**
Task 1 instructs preserving the `## Фоновый режим Android` section (`:74-76`) unchanged. That section currently says the FGS "запускается при `ModuleSessionStarted` и останавливается при `ModuleSessionEnded` или `ModuleSessionAbandoned`". Per note 07 (already shipped), `KeepAliveCoordinator` now **also** starts on the breath activity's local `isLive` edge (`KeepAliveCoordinator.dart:37-44`, wired at `BreathModule.dart:57`) and stops on `SessionTerminated` (`:54-55`) — the offline path the server events miss. So the "preserve as-is" instruction preserves a partial inaccuracy. This predates the root/child work and is tangential to the milestone, so it is non-blocking — but the author should verify the FGS section against the actual coordinator rather than blindly preserving it, and keep it behaviour-level (drop the raw `ModuleSession*` event-enum names per the describe-behaviour guard).

**3. Minor — meditation doc intro (`:3`, `:11`) also carries code-shaped lifecycle content.**
Task 3 explicitly targets `:74` and the `## Реализация` block `:52-72`, but the lifecycle intro (`:11`) also dumps `channel.start(...)`, `_started`/`_ended` flags and `dispose()`-shaped detail, and `:3` mirrors it. These fall under Task 3's general "root/child + describe-behaviour" mandate, but calling them out explicitly would prevent the rewrite from stopping at `:74` and leaving `:11` code-shaped and still implying object-teardown semantics.

### Positive Notes
- Correctly sequenced as the final milestone — verified all upstream behaviour is committed, so the docs describe genuine current state.
- Precise, accurate line anchors for every section being reworked.
- Strong, specific guards that eliminate the two known myths ("one active session per user", server-side pause filtering) and the FSM/internal-code leakage.
- Task dependencies are sound (Task 2 and Task 3 both depend on Task 1's core-model rewrite).
- The pause-section correction (client ceases emitting phases; the gap is client-produced) matches the code and the spec note exactly — a subtle point handled correctly.
