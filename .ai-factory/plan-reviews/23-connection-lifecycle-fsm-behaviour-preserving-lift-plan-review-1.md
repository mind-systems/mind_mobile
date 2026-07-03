## Code Review Summary

**Artifact Reviewed:** `plans/23-connection-lifecycle-fsm-behaviour-preserving-lift.md`
**Files it targets:** `lib/Core/Grpc/ConnectionLifecycle.dart` (new), `lib/Core/Grpc/ModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`
**Risk Level:** 🟢 Low

The plan is a well-scoped, behaviour-preserving structural lift. All source line references (`_openSessionStream:90`, first-frame gate `:101`, `onError:120`, `onDone:126`, `disconnected:77`, `_reset:325`, `isConnected:51`, `_backoffConfirmed:44`) match the current file exactly, and all test references (`isConnected` at `:850/:934/:1099/:1027`, confirm group at `:891`) are accurate. The behaviour-preservation mapping onto the golden master is sound. One issue below is worth pinning before implementation to avoid a red suite.

### Context Gates

- **Roadmap (PASS):** The plan links cleanly to `ROADMAP.md:80` ("Connection-lifecycle FSM (behaviour-preserving lift)") under "Phase — Connection-lifecycle refactor". Contract line, enum shape `{disconnected,opening,active,reconnecting,yielded}`, the single `_transition` chokepoint, and the dormant-`yielded` constraint all match the plan verbatim. Spec note path `.ai-factory/notes/25-rootchild-connection-lifecycle-fsm.md` is correct and present.
- **Rules (PASS):** `RULES.md` covers Module Service statelessness, App.dart hygiene, and constructor injection — none apply to `ModuleStateChannel` (core gRPC infra, not a module Service). No violations.
- **Architecture (PASS):** The change stays entirely inside `lib/Core/Grpc/`, respects the one-type-per-file enum convention (mirrors `GrpcConnectionState.dart`, a single-line enum, and `ModuleState.dart`). No boundary or dependency violations.

### Critical Issues

None blocking.

### Issues / Guidance

**1. (WARN) The `isConnected` "either derive from `_lifecycle` or keep `_sessionSub`-backed" fork is not actually a free choice — only the `_sessionSub`-backed option is correct.**
Task 3 (`:39`) presents both as equally valid "whichever keeps assertions green". They are not equivalent, and the derive-from-`_lifecycle` option would **break the golden master** and **violate the note's behaviour-preservation invariant**:

- **Dispose breaks the suite.** `dispose()` (`:334`) calls `_closeSessionStream()` (nulls `_sessionSub`) but does **not** call `_transition`. If `isConnected` is derived as `_lifecycle == opening || active`, then after dispose `_lifecycle` remains `opening`/`active` → `isConnected` returns **true**, failing the assertion at test `:1107` (`should close the session stream and report isConnected=false after dispose`).
- **Reset diverges (test-invisible but violates the invariant).** `_reset()` (`:325`) transitions to `disconnected` but does **not** call `_closeSessionStream()`, so `_sessionSub` stays non-null. Original `isConnected` = `_sessionSub != null` = **true**; a lifecycle-derived predicate = **false**. No existing test catches this (Group 8 only asserts `currentState.status`), but it silently breaks the note's requirement that `isConnected` stay "identical to `_sessionSub != null`".

**Recommendation:** State explicitly in Task 3 that `isConnected` MUST remain backed by `_sessionSub` (`bool get isConnected => _sessionSub != null;` — leave it untouched). Drop the "derive from `_lifecycle`" option, or, if kept, add a `_transition` in `dispose()` and `_reset()` and route `isConnected` through a predicate that also accounts for the un-closed stream after reset — which is strictly more work for zero benefit. The simplest behaviour-preserving path is: **do not touch `isConnected`.** Note that `ModuleStateChannel.isConnected` has no `lib/` readers (only tests), so leaving it `_sessionSub`-backed is fully safe.

**2. (INFO) `confirmConnected` "exactly once per stream open" across reconnect — verified correct.**
The FSM mapping preserves the re-arm: after `onError`/`onDone`/`disconnected` the channel lands in `reconnecting`, and the next `connected` runs `_openSessionStream()` → `_transition(opening)` unconditionally, so the next first frame does `opening → active → confirmConnected()` again. This matches the original `_backoffConfirmed = false` re-arm on every open. The `opening`-gated first-frame check is equivalent to `!_backoffConfirmed` because `_openSessionStream` is the only entry that sets `_sessionSub` and it always transitions to `opening` first. No defect.

**3. (INFO) Spec note line references are stale, but the plan's are current.**
`notes/25-*.md` cites `isConnected :40`, `_backoffConfirmed :33`, `_reset :222-226`, `:83-86`, `:101-113` — these are from an older revision (actual: `:51`, `:44`, `:325`, first-frame `:100-103`, handlers `:120-131`). The **plan** uses the correct current numbers throughout, so no action is needed; flagging only so the implementer trusts the plan's line numbers over the note's.

**4. (INFO) Sibling `ModuleInstructionStream.dart` carries the same `_backoffConfirmed` flag-soup (`:23/:121/:126`).** Correctly out of scope for this milestone — noting only as a future FSM-lift candidate; the plan should not touch it.

### Positive Notes

- **Scope discipline is excellent.** The plan repeatedly and correctly walls off the command-lifecycle guards (`_isPendingStart`/`_isPendingPause`) as owned by the start-race impl, and keeps `yielded` dormant with an explicit "no transition reaches it" instruction plus a placeholder comment — directly addressing the flag-soup failure mode the spec note diagnosed.
- **`_transition` kept side-effect-free** (log + assign only, no stream/socket calls) is the right call for a behaviour-preserving lift; dropping the note's "guard" (throwing on illegal transitions) is safer here since a guard could introduce new runtime behaviour.
- **Test strategy is correctly additive** — appending a small FSM-state group on top of the green golden master, with a dormancy assertion for `yielded`, rather than rewriting. Matches the decompose-skeleton "refactor under existing tests" verdict.
- **Ordering preserved** in `onError`/`onDone` (`_closeSessionStream` → `disconnect` → `scheduleReconnect` → `_transition(reconnecting)`) keeps `disconnectCount`/`scheduleReconnectCount` and the immediate `isConnected=false` read intact.

Address guidance item 1 (pin `isConnected` to the `_sessionSub`-backed form) and the plan is ready to implement. Because that is a clarification the plan already permits as one of its two options rather than a missing step or wrong assumption, it does not block ratification.

PLAN_REVIEW_PASS
