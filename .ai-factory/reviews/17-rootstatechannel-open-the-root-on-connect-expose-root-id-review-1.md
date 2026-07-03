# Code Review: `RootStateChannel` — open the root on connect, expose `root.id`

**Scope:** code changes in `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/RootStateChannel.dart` (new), `lib/Core/App.dart`.
**Verification:** read all changed files in full plus surrounding consumers (`BreathModuleStateChannel`, `MeditationModuleStateChannel`, `KeepAliveCoordinator`, `BiometricStreamClient`, `SessionRegistry`, generated `module_state.pbenum.dart`/`module_state.pb.dart`). Ran `flutter analyze` (clean) and the full channel/registry/adapter/keepalive/bio test suites (127 passing).

## Result

No correctness, security, or runtime-safety defects found. The implementation matches the plan and the code behaves correctly at the boundaries examined.

## What was checked (evidence)

- **ROOT frames never touch the legacy single-state (Task 1).** `_processProtoEvent` (`ModuleStateChannel.dart:145-150`) maps `event.activityType` first and early-returns into `_handleRootFrame` for `ActivityType.root`, so a ROOT `ACTIVE`/`RESUMED` frame no longer overwrites `_state` nor emits `ModuleSessionStarted`. This correctly prevents (a) `BreathModuleStateChannel._channelSub` (`:45-48`) from latching the root's id as the child's `moduleSessionId`, (b) `KeepAliveCoordinator._onEvent` (`:48`) from starting the FGS on every connect, and (c) `BiometricStreamClient` (`:88`) from latching `_currentSessionId` to the root before note 17 retargets it.

- **Unset `activityType` is safe.** Confirmed `ACTIVITY_TYPE_UNSPECIFIED = 0` is the proto default (`module_state.pbenum.dart:24`) and `_mapActivityTypeFromProto` returns `null` for it (logs "dropping unknown"), so child/terminal/reset frames that omit `activityType` (`COMPLETED`, `ABANDONED`, `ACTIVITY_STATUS_UNSPECIFIED`, `no_active_session`) fall through to the existing single-state logic unchanged. Verified live: the six registry-routing tests, including "child COMPLETED keeps root" and "UNSPECIFIED clears", stay green.

- **`refId ?? '' → refId` is behavior-preserving (Task 2.3).** Generated `ActivityStartCmd` omits the field when the arg is null (`module_state.pb.dart:35`). Both child call sites pass a non-null `String` (`BreathModuleStateChannel.dart:90` `_sessionId`; `MeditationModuleStateChannel.dart:49` `_refId`, typed `final String`), so children are unaffected; only the root (via `startRoot`, which never sets `refId`) leaves it unset, as required.

- **`startRoot()` correctly bypasses the child guard (Task 2.1).** It sends directly via `_sendSessionRequest` without consulting the `currentState.status == active || _isPendingStart` guard and without mutating `_isPendingStart`, so it re-sends on every reconnect (even while a child is active / `currentState` is stale-active) and cannot block a subsequent child `start()`. Silent-drop when the sink is gone is acceptable.

- **`sessionStreamOpened` timing has no missed-first-open race (Task 2.2 / Task 3).** `RootStateChannel` is constructed synchronously in `initialize()` immediately after `moduleStateChannel` (`App.dart:225`), before any async `connected` transition fires `_openSessionStream()`. `_sessionStreamOpened.add(null)` fires at the end of `_openSessionStream` (`:133`) after `_sessionSink`/`_sessionSub` are assigned, so by the time the listener's `startRoot()` runs the sink exists. `PublishSubject` is non-replaying, but subscription precedes the first emit, so nothing is dropped. Closed in `dispose()` (`:335`).

- **Idempotent reconnect / no duplicate root.** The registry is not cleared on transport drop, so `rootId` stays resolvable across reconnect; the re-sent `start{ROOT}` upserts the same id. Root-only-active leaves `currentState` idle, which is the correct semantics for "no active child" and does not corrupt reconnect resume metadata.

- **Wiring (Task 4).** Field, constructor param, and construction are threaded correctly in `App.dart`; `flutter analyze` clean.

## Non-blocking observations (advisory, not defects)

- **New `confirmConnected` side effect.** Because `startRoot` now guarantees a server response frame on every connect, the ROOT frame drives the `_backoffConfirmed`/`confirmConnected()` path (`:101-104`) even on a fresh connect that previously produced no frames. This is a benign improvement (the connection is confirmed by a real response), not a regression — flagging only so it is a known, intentional change.

- **No automated coverage for the three new behaviors** (ROOT frame emits no legacy event / re-send on every `sessionStreamOpened` / `refId` omitted). Consistent with the plan's explicit `Testing: no` and already noted in the plan review. Existing suites stay green; a single test asserting "a ROOT `ACTIVE` frame sets `rootId` but emits no `ModuleSessionStarted` and leaves `currentState` idle" would cheaply lock in the core invariant if desired.

REVIEW_PASS
