## Plan Review — Retarget the bio stream to `root.id` (round 2)

**Files Reviewed:** 1 plan + verified against 6 source/test files
**Risk Level:** 🟢 Low

The plan is architecturally sound, every line reference is accurate to the current
code, and every predicted test outcome was traced and confirmed. No blocking issues.
The items below are advisory (one cross-artifact inconsistency, two clarifications).

---

### Verification (all confirmed against code)

- **Line references are exact.** Constructor initializer list (`BiometricStreamClient.dart:69-71`),
  the root-id seam already present as a no-op (`:29` `_rootIdSub`, `:87` subscribe, `:116`
  `_onRootIdChanged`), disconnect case `_sessionConfirmed = false` (`:77-79`), send gate
  (`:121`), encode path (`:210-245`), `App.dart` client construction (`:234`), and
  `rootStateChannel` built earlier at `:225` — all match.
- **`rootIdChanges` is a seeded, `.distinct()` `String?` stream.** Confirmed
  `SessionRegistry.dart:16` `BehaviorSubject<String?>.seeded(null)` exposed via `.distinct()`
  at `:73`; surfaced by `ModuleStateChannel.rootIdChanges` (`:37`) → `RootStateChannel.rootIdChanges`
  (`:28`). A late subscriber (the client) receives the current value immediately.
- **The reconnect hazard is real and grounded.** `ModuleStateChannel` clears the registry
  only on `GuestState` logout (`:84` → `_reset` → `:329`), `no_active_session` (`:112-114`),
  or an `UNSPECIFIED` frame (`:190`) — **not** on a transient `disconnected`/`connected`
  cycle (`:75-81` only closes/reopens the session stream). On reconnect `RootStateChannel`
  re-sends `startRoot()` (`:21-24`), the server re-emits the same ROOT frame, `_registry.upsert`
  recomputes the same `root.id`, and `.distinct()` (`SessionRegistry.dart:73`) suppresses it —
  so `_onRootIdChanged` is **not** re-entered. The plan's fix (do not clear `_sessionConfirmed`
  on disconnect when root-sourced) is therefore the correct remedy, not an optimization.
- **All four existing routing tests stay green under the plan.** Traced each:
  root-1 wins over a later `ModuleSessionStarted(child-A)` (lifecycle early-return); child end
  does not clear the id; `rootIdChanges.add(null)` clears the id + empties the ring while
  the sink stays open so `injectReady` drains nothing; and the pre-root gate holds.
- **The golden-master file stays green.** In legacy mode (`_rootSourced == false`, no
  `rootIdChanges`), `_onLifecycleEvent` still drives the id and disconnect still clears
  `_sessionConfirmed` — preserving "drop sendBatch after disconnect", resume-reconfirm,
  cooldown, replay-ring, and readiness tests.
- **`final bool _rootSourced` in the initializer list is valid Dart** — `rootIdChanges` is a
  constructor parameter in scope there; the plan's warning against `late final`/dropping
  `final` is correct.
- **Phase path is genuinely decoupled.** `BreathModuleStateChannel` tags phase samples with
  its own child `_moduleSessionId` via `_instructionStream.sendSample(...)`
  (`BreathModuleStateChannel.dart:76,141,148`) — it never touches `BiometricStreamClient`.
  The "do not modify the phase path" guard is valid.
- **No other consumers break.** `biometric_batcher_test.dart` uses a
  `_FakeBiometricStreamClient implements BiometricStreamClient` (`:44`), so the new
  constructor parameter does not affect it.

### Context Gates

- **Architecture / RULES.md:** ✅ Pass. RULES.md rule 3 ("all dependencies injected via
  constructor; let the class manage its own subscription") is honored — Task 2 passes the
  existing `rootStateChannel.rootIdChanges` stream in through the constructor and the client
  owns `_rootIdSub`. RULES.md rule 2 (App.dart is infrastructure-only) is honored — no new
  module state is introduced; only an existing infrastructure stream is wired.
- **Roadmap:** ✅ Pass. ROADMAP.md Phase 63 line 68 ("Retarget the bio stream to `root.id`")
  matches the plan title and scope verbatim; governing spec `notes/17-rootchild-bio-to-root.md`.
- **Spec tree — ⚠️ WARN (non-blocking): the plan correctly contradicts its governing spec.**
  Note 17 §Change (line 22) instructs: *"Keep the `disconnect` path clearing `_sessionConfirmed`
  and re-arming on reconnect (root id re-learned via note 15 re-open)."* That instruction is
  **falsified** by `SessionRegistry.rootIdChanges` being `.distinct()` (verified line 73): the
  re-open re-emits the *same* id, which is suppressed, so nothing re-arms `_sessionConfirmed`.
  The plan's deviation (Task 1, bullet 4 — guard the clear with `if (!_rootSourced)`) is the
  right call and is well-justified in Key findings §18. **The plan needs no change**, but
  note 17 is now stale and literally prescribes the reconnect bug it was meant to avoid.
  Recommend reconciling note 17 §22 so a future implementer/reviewer working from the spec
  tree does not re-introduce the disconnect-clear. This is a spec-note fix, outside the plan's
  own scope.

### Recommended clarifications (minor)

1. **Task 3 — make the cooldown advance mandatory, not conditional.** The new reconnect test
   will only pass if the clock is advanced past the 2 s reopen cooldown between
   `disconnected` and `connected`. Without a custom `clock`, `_clock` defaults to
   `DateTime.now`, which is **not** frozen by `fakeAsync`; the first send set `_lastOpenAttempt`,
   so on reconnect `_ensureSinkOpen` (`:145-148`) is cooldown-blocked, no fresh stream opens,
   and the assertion on `stub.latest` fails (or crashes on `connections.last`). The plan
   flags this only parenthetically ("clock if a cooldown advance is needed"). Recommend
   stating it as a requirement: the test **must** inject a `clock` and advance it > 2 s after
   teardown, mirroring the golden-master reconnect test (`biometric_stream_client_test.dart:494-553`,
   `fakeNow.add(Duration(seconds: 3))` + `async.elapse`).

2. **Class docstring drift (hygiene).** `BiometricStreamClient`'s class comment (`:14-24`)
   describes "current-module-session gating" and "Session ended / abandoned clears the ring."
   Both become inaccurate in root-sourced mode (id tracks the root; child end no longer
   clears). The plan sets Docs: no, so this is optional, but a one-line docstring touch keeps
   the class comment truthful.

### Positive Notes

- The dual-mode (`_rootSourced`) switch is the sanctioned way to satisfy note 23's
  "golden master never edited" constraint while flipping production to root-sourcing — the
  legacy branch exists only for that never-edited test; production always runs root-sourced
  after Task 2. Acceptable, deliberate, and clearly reasoned in the plan.
- The plan's line numbers are updated relative to the (stale) note-17 references and match
  the actual current file — good diligence.
- The reconnect hazard, its `.distinct()` root cause, and the exact fix are all captured with
  correct rationale; Task 3 targets precisely the gap the four existing tests miss.
- `SESSION_NOT_FOUND` / no-proto-change / phase-path guards are all correctly scoped as
  "do not touch," consistent with notes 17 and 23.

### Verdict

No blocking correctness, architecture, migration, or security issues. The plan is
implementable as written and will turn the note-23 routing tests green while keeping the
golden master green. Two small tightenings (make Task 3's clock-advance explicit; reconcile
stale note 17 §22) are recommended before/alongside implementation.
