## Code Review Summary

**Artifact Reviewed:** Plan `28-pending-start-state-lift-behaviour-preserving.md`
**Files Reviewed:** 1 plan + target `lib/Core/Grpc/ModuleStateChannel.dart` + 4 pinned test suites + spec note 28
**Risk Level:** 🟢 Low

### Context Gates

- **Roadmap linkage (OK):** Plan title matches `ROADMAP.md:99` ("Pending-start state lift (behaviour-preserving)"), which names the same `Spec:` note (`.ai-factory/notes/28-rootchild-pending-start-state-lift.md`) and the same chokepoint framing. The downstream task (`:100`, note-29 per-child RESUMED) is correctly declared out of scope, matching the roadmap contract ("Route through the note-28 chokepoint"). Linkage is complete.
- **Spec note (OK):** The plan faithfully implements note 28's fix shape — explicit states + one guarded chokepoint owning `isConnected` + 3-attempt budget, keeping it command-level and out of the note-25 `ConnectionLifecycle` FSM, and explicitly not folding in note 29.
- **RULES.md (N/A):** The three project rules concern Module Services / App.dart wiring / constructor DI — none touch this internal `ModuleStateChannel` refactor. No violation.
- **ARCHITECTURE.md (OK):** No boundary/dependency impact; the change is confined to one existing infrastructure class.
- **skill-context (N/A):** No `.ai-factory/skill-context/aif-review/SKILL.md` present.
- **Migrations (N/A):** Pure Dart refactor, no Drift schema or proto change.
- **Security (N/A):** No auth, input, or transport-surface change.

### Verification of Plan Accuracy

Cross-checked every claim against the live source (HEAD `0f1bac5`; spec references `93f3e92`):

- **Line references are correct.** `_onConfirmTimeout` is `:502-517`, and its inline budget + `isConnected` branches are `:505-516` (Task 2 ✓). `_resolveSettling` is `:551-572` (Task 3 ✓).
- **`_beginStart` uniform-send claim holds.** For a carried/armed pending, `_pendingStarts[p.type]` is already `p`, so `_beginStart` performs a self-assign + redundant (already-null during settling) timer cancel + `_sendStart` — behaviourally identical to today's direct `_sendStart(p)`. For a released deferred start it registers then sends. The chokepoint's `sent` branch is therefore genuinely uniform (✓).
- **Deferred-release budget check is a no-op (correct).** A deferred start is always `attempts == 0` (created in `start()`, never sent while in `_deferredStarts`), so routing it through `_resolveStart`'s `attempts >= 3` gate never fires — no behaviour change on the deferred path.
- **`carriedTypes` snapshot ordering preserved.** Current code snapshots `_pendingStarts.keys` *before* the deferred loop; Task 3 explicitly keeps this, so a freshly-released deferred start (now in `_pendingStarts`) is not double-sent. Correct.
- **`_onConfirmTimeout` held/re-arm equivalence holds.** `_resolveStart` returns `held` from the `!isConnected` branch without touching `p.timer` or `p.attempts`; the caller re-arms exactly as today (no attempt consumed).
- **Golden master (`start_race_giveup_contract_test.dart`) stays green.** Traced the "3-attempt-spent carried pending gives up ... no 4th send" test: at `_resolveSettling` time the stream has been reopened, so `isConnected == true`; the carried breath pending has `attempts == 3` → `_resolveStart` returns `gaveUp` via `_giveUp` → one `SessionStartFailed(breath)`, no 4th send. Identical outcome under the refactor.

### Critical Issues

None. The refactor is sound and, in every path exercised by the four pinned suites, behaviour-identical.

### Observations (non-blocking)

1. **Disclosed ordering divergence — keep it disclosed in the commit.** The Constraints section and Task 3 intentionally flip the carried-loop precondition order from today's `isConnected`-then-budget to the chokepoint's budget-then-`isConnected`. This is a genuine (if micro) behaviour change on one edge: a carried pending with `attempts >= 3` **and** `isConnected == false` at settling-resolve now emits `SessionStartFailed` + removes the pending, where today's `_resolveSettling` `continue`s and leaves it dormant. The plan is transparent that this edge is untested and pinned by no assertion, and grounds "behaviour-preserving" in the four suites staying green. That is a defensible reading and I concur it is safe — but it is a slight tension with the spec note's stricter phrasing ("no observable behaviour change"). Recommendation: carry the plan's own justification (unifies historically-inconsistent ordering; edge confined to budget-spent + transport-down at settling-resolve) into the commit message so the divergence is not later mistaken for a regression. No code change required.

2. **`start()`'s initial send correctly bypasses the chokepoint.** `start()` (`:393-419`) calls `_beginStart` directly and evaluates *neither* precondition (no budget, no `isConnected`) — routing it through `_resolveStart` would change behaviour (a `!isConnected` start would become `held` instead of sent-and-dropped-with-retry-armed). The plan rightly scopes the chokepoint to *resolution* triggers only, and Task 5's audit ("no caller re-checks `isConnected`/budget outside `_resolveStart`") passes because `start()` re-checks neither. Worth an implementer being aware of so they don't "helpfully" reroute it.

3. **Task 4 state-doc completeness (minor).** The five-state enumeration is the right level of documentation, but `_openSessionStream`, `_resetWholeTree`, and `dispose` also mutate `_pendingStarts` timers (cancel-on-reconnect → "carried"; clear-on-reset → terminal). Consider having the state-model comment note these lifecycle transition sites so the map is complete. Purely documentary; no logic impact.

4. **Task 5 runs the whole `test/Core/Grpc/` directory** (a superset of the four pinned files), which is good — it also guards `reconnect_eviction_contract_test.dart` and `module_instruction_stream_test.dart`, which exercise `ModuleStateChannel` too. The byte-unchanged `git diff --stat test/` check on the four pinned files is the correct behaviour-preservation gate.

### Positive Notes

- The plan correctly identifies that `_beginStart` already unifies the carried/deferred send paths, so the chokepoint composes existing helpers rather than duplicating `_sendStart`/`_giveUp` bodies — matching the spec's "enum secondary, chokepoint load-bearing" directive and avoiding a cargo-culted `_transition` hub.
- Dependency ordering (Task 1 first; 2/3/4 depend on it; 5 verifies) is right, and the single-commit boundary keeps the behaviour-preserving refactor atomic.
- Every hold strategy is left in its caller reading only the abstract `held` outcome — a clean separation that makes the note-29 seam (`_clearPendingStart` as the sole confirmed-resolution point) genuinely pluggable without re-stating preconditions.
- The plan is unusually honest about its one intentional divergence rather than hiding it — this is exactly the kind of disclosure that prevents the next review round.

PLAN_REVIEW_PASS
