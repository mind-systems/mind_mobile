## Code Review Summary

**Artifact:** Plan `17-rootstatechannel-open-the-root-on-connect-expose-root-id.md`
**Files Reviewed:** 4 target files + 5 supporting files (plan targets: `ModuleStateChannel.dart`, `RootStateChannel.dart` (new), `App.dart`; verified against `BreathModuleStateChannel.dart`, `SessionRegistry.dart`, `KeepAliveCoordinator.dart`, `BiometricStreamClient.dart`, generated `module_state.pb.dart`, existing tests)
**Risk Level:** 🟢 Low

### Context Gates

- **Roadmap linkage — PASS.** The plan maps cleanly to `ROADMAP.md:59` (`RootStateChannel — open the root on connect, expose root.id`, Spec: `.ai-factory/notes/15-rootchild-root-state-channel.md`). Every contract clause in the roadmap line is honored by the plan: app-level sibling wired in `App.dart` (not screen-scoped), `activity:start{ROOT}` idempotent per user, `root.id` read from the `activity_type==ROOT` frame via registry `rootId`, root open **not** gated on biodata, and no end/stop/pause/resume (`CANNOT_END_ROOT`). The prerequisite milestone (`ROADMAP.md:52`, registry contract) is `[x]` and present in the code (`SessionRegistry`, `ModuleSession`, routing).
- **Architecture gate (`.ai-factory/ARCHITECTURE.md`) — PASS.** `RootStateChannel` is connection-level infrastructure living in `lib/Core/Grpc/`, mirroring `KeepAliveCoordinator` / `BiometricStreamClient` / `instructionStream` — all infra constructed in `App.initialize()`. No layering violation.
- **Rules gate (`.ai-factory/RULES.md`) — PASS with one note (WARN).**
  - Rule "never add module-specific state/streams/triggers to App.dart — infra only": `RootStateChannel` is **not** module-specific; it is connection infra, exactly the `KeepAliveCoordinator` precedent. Compliant.
  - Rule "all deps via constructor; never wire a class from outside by subscribing on its behalf": the plan has `RootStateChannel` take `channel` in its constructor and subscribe to `channel.sessionStreamOpened` **itself** — App.dart does not subscribe on its behalf. Compliant.
  - The "Module Services must be stateless" rule does **not** apply — `RootStateChannel` is an adapter/coordinator, not an `IXxxService` implementation, and holding a `StreamSubscription` + `dispose()` is the established pattern (`BreathModuleStateChannel`, `KeepAliveCoordinator`).

### Critical Issues

None. All line references, API shapes, and behavioral assumptions in the plan were verified against the current code and hold.

### Verified Assumptions (evidence)

- **Task 1 routing does not break existing registry tests.** I traced all six ROOT-touching tests in `test/Core/Grpc/module_state_channel_test.dart` (lines 1131–1317):
  - `root+breath → rootId/childOfType` (1133): ROOT `ACTIVE` upserts registry via `_handleRootFrame`, BREATH `ACTIVE` falls through → both green.
  - `child COMPLETED keeps root` (1158): the `COMPLETED` frame carries **no** `activityType` (defaults unset → `_mapActivityTypeFromProto` returns `null`), so it falls through to the existing `removeTerminal(breath-1)` branch, root survives. Green.
  - `UNSPECIFIED clears` (1239): the `ACTIVITY_STATUS_UNSPECIFIED` frame also carries **no** `activityType`, so it falls through to the existing `_registry.clear()` branch. Green. **This is load-bearing** — the plan's `_handleRootFrame` "ignores other statuses," so it only stays green because the reset frame is untyped, not ROOT-typed. Correct in practice (global reset frames carry no type), and worth the implementer keeping intact.
  - logout (1270) and `no_active_session` (1292) are handled by the auth/`sessionError` paths, untouched by Task 1. Green.
- **`refId ?? '' → refId` change is safe (Task 2.3).** Generated `ActivityStartCmd` (`module_state.pb.dart:35`) does `if (refId != null) result.refId = refId;` — confirmed: passing `refId: null` leaves the field unset. Existing tests always pass a concrete `refId` (`'sess-1'` or explicit `''`), and none assert on `hasRefId()`, so none break. `BreathModuleStateChannel.dart:90` always passes `_sessionId`, so child behavior is unchanged.
- **The FGS / bio mis-tagging hazard is real and correctly targeted.** `KeepAliveCoordinator.dart:48` starts the foreground service on `ModuleSessionStarted`, and `BiometricStreamClient.dart:88` latches `_currentSessionId` on it. Today `_upsertRegistryEntry` runs for **all** `ACTIVE`/`RESUMED` types *and* the ACTIVE branch emits `ModuleSessionStarted` — so without Task 1 a ROOT `ACTIVE` frame would (a) overwrite the single `_state` that `BreathModuleStateChannel._channelSub` reads (`:45-48`) and (b) fire the FGS on every connect. Early-returning ROOT frames to the registry is the right fix.
- **Line references are accurate.** `App.dart`: `moduleStateChannel` field `:98`, `App._` param `:132`, construction `:221`, `shared = App._(...)` `:254` — all correct. `ModuleStateChannel.dart`: `_processProtoEvent` `:137`, `start()` guard `:206`, `refId ?? ''` `:211`, `_openSessionStream` `:83-126`, silent-drop `:246-249`, `dispose()` `:287` — all correct.
- **`sessionStreamOpened` timing is safe.** `RootStateChannel` is constructed synchronously in `initialize()` immediately after `moduleStateChannel`, long before the first async `connected` event fires `_openSessionStream()`. This is the identical subscribe-before-first-emit contract `KeepAliveCoordinator` and `BiometricStreamClient` already rely on for the `PublishSubject` `events` stream, so a non-replaying `PublishSubject` for `_sessionStreamOpened` will not miss the first open.
- **`startRoot()` bypass is correct.** Sending via `_sendSessionRequest` (silent drop if sink gone) and deliberately not touching `_isPendingStart` avoids both (a) blocking the required reconnect re-send on a stale-active `currentState` and (b) wrongly blocking a subsequent child `start()`.

### Non-blocking Notes (WARN)

- **Testing: no — silent-failure surface left uncovered.** The three genuinely new behaviors this plan introduces are silent-failure-prone: (1) ROOT frames must never touch `_state`/emit `ModuleSessionStarted`, (2) `startRoot()` must re-send on every `sessionStreamOpened` yielding the same `rootId` with no FGS side-effect, (3) `startRoot()` must omit `refId`. The existing registry tests (milestone `:52`) cover routing-by-type but **not** these. Unlike the bio milestone (`ROADMAP.md:67`), this milestone has no paired TDD-test line, so per the project's own "test only silently-failing surfaces" philosophy there is a small gap. This is consistent with the plan's explicit `Testing: no` and its "existing tests stay green" guard — flagging as advisory, not a blocker. If the orchestrator wants cheap insurance, a single test asserting "a ROOT `ACTIVE` frame sets `rootId` but emits no `ModuleSessionStarted` and does not change `currentState`" would lock in the core invariant.
- **`dispose()` on `RootStateChannel` is a test-seam only** (like `KeepAliveCoordinator.dispose`) — production never calls it because the adapter lives for the app lifetime. The plan is consistent in not wiring an App-level dispose call; just confirming this is intentional, not an omission.

### Positive Notes

- Exceptionally precise plan: every file path, line anchor, generated-code detail, and downstream-consumer reference checks out against the current tree.
- The rationale sections correctly identify the exact failure modes (FGS-on-connect, bio mis-tag, single-state overwrite of the child's `moduleSessionId`) and tie them to concrete call sites.
- Idempotent-per-user reconnect design (re-send on every stream-open, registry-derived `rootId`) is coherent with the later reconnect milestone (`ROADMAP.md:79`, note 20) which explicitly re-learns `root.id` from this adapter's ROOT re-open rather than the reconnect fan-out.
- Correctly scopes out end/stop/pause/resume for the root and fixes the pre-existing `refId ?? ''` smell opportunistically without changing child behavior.

PLAN_REVIEW_PASS
