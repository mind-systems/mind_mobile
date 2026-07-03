# Plan: `RootStateChannel` — open the root on connect, expose `root.id`

## Context
Adds an app-level sibling adapter that sends `activity:start{ROOT}` each time the control tunnel opens (idempotent per user) and exposes the registry-derived `root.id`, so later phases can tag bio to the root while children link server-side. Root frames drive only the session registry — never the legacy single-state — and the root has no end/stop/pause/resume path (`CANNOT_END_ROOT`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Channel-level root support

- [x] **Task 1: Route ROOT frames to the registry only, never the legacy single-state**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_processProtoEvent` (`:137`), before the existing status branches, map `event.activityType` via `_mapActivityTypeFromProto` and, when it is `ActivityType.root`, hand off to a new private `_handleRootFrame(event)` and `return` — so ROOT frames never touch `_state`/`_events`. `_handleRootFrame` upserts the registry (reuse `_upsertRegistryEntry`) on `ACTIVE`/`RESUMED`, calls `_registry.removeTerminal(event.moduleSessionId)` defensively on `COMPLETED`/`INTERRUPTED`/`ABANDONED` (root should never end), and ignores other statuses. Only early-return for `== ActivityType.root`; a `null` map result or child types (`breath`/`meditation`) must fall through to the existing single-state logic unchanged. Rationale: once the client sends `start{ROOT}`, the ROOT `ACTIVE` frame would otherwise overwrite the single `_state` (which `BreathModuleStateChannel._channelSub` reads for its `moduleSessionId`, `BreathModuleStateChannel.dart:45-48`) and emit `ModuleSessionStarted`, which `KeepAliveCoordinator` (`KeepAliveCoordinator.dart:48`) and `BiometricStreamClient` (`BiometricStreamClient.dart:88`) both react to — starting the FGS on every connect and mis-tagging bio before note 17 retargets it. The existing registry-routing tests in `test/Core/Grpc/module_state_channel_test.dart` (`ROOT`+`BREATH` → `rootId`/`childOfType`, child-`COMPLETED`-keeps-root, `UNSPECIFIED`/logout/`no_active_session` clears) must stay green.

- [x] **Task 2: Add `startRoot()`, a stream-opened signal, and unset `refId` when null** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Three changes:
  1. Add `startRoot()` that sends `proto.StateRequest(activityStart: proto.ActivityStartCmd(activityType: proto.ActivityType.ROOT))` with `refId` **omitted** (root has no ref — `mind_api` note 34) and no `clientTimestampMs`. It must **bypass** the child single-session guard in `start()` (`:206`) and must **not** touch `_isPendingStart` (root is idempotent server-side; blocking it on a stale-active `currentState` would prevent the required re-send on reconnect, and setting `_isPendingStart` would wrongly block a child start). It sends via `_sendSessionRequest` (drops silently if the sink is gone, which is fine).
  2. Add a stream-opened signal: a `PublishSubject<void> _sessionStreamOpened` with a public `Stream<void> get sessionStreamOpened`, fired with `_sessionStreamOpened.add(null)` at the **end** of `_openSessionStream()` (`:83-126`), after `_sessionSink`/`_sessionSub` are assigned. Close it in `dispose()` (`:287`). This gives `RootStateChannel` a deterministic "sink now exists" trigger (sending before the sink exists is silently dropped, `:246-249`).
  3. Fix the `refId ?? ''` smell in `start()` (`:211`): pass `refId: refId` so a null `refId` leaves the optional proto field **unset** (`ActivityStartCmd` already omits it when null — generated `module_state.pb.dart:35`) instead of sending `''`. Children always pass a real `refId` (breath passes `_sessionId`), so their behavior is unchanged.

### Phase 2: Root adapter + wiring

- [x] **Task 3: Add the `RootStateChannel` adapter** (depends on Task 2)
  Files: `lib/Core/Grpc/RootStateChannel.dart`
  New app-level sibling adapter (modeled on `BreathModuleStateChannel`, but tied to the connection, not a screen). Constructor takes the `ModuleStateChannel`; it subscribes to `channel.sessionStreamOpened` and calls `channel.startRoot()` on **every** emission — so the root is (re)opened on first connect and each reconnect (idempotent per user → same `root.id`, no duplicate). Expose the root id for downstream consumers (note 17 bio) by delegating to the registry getters already on the channel: `String? get rootId => _channel.rootId` and `Stream<String?> get rootIdChanges => _channel.rootIdChanges`. Add `dispose()` that cancels the subscription. No end/stop/pause/resume path exists on this adapter at all. Use `logPrint` (via `package:mind/Logger.dart`) for a single "opening root" log line on send.

- [x] **Task 4: Wire `RootStateChannel` into `App.dart`** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Add the import, a `final RootStateChannel rootStateChannel;` field (declared near `moduleStateChannel`, `:98`), and thread it through the private `App._` constructor (`:132`). In `initialize()`, construct it immediately after `moduleStateChannel` (`:221`): `final rootStateChannel = RootStateChannel(channel: moduleStateChannel);` and pass it into `shared = App._( ... rootStateChannel: rootStateChannel, ... )` (`:254`). This must be created during app init so the root opens as soon as the tunnel is up, independent of any screen. Do not gate its construction on biodata or on any session — root open is unconditional.

## Verify (acceptance behaviors)
- On connect, exactly one `start{ROOT}` is sent and `rootStateChannel.rootId` becomes non-null from the `activity_type == ROOT` response frame.
- A reconnect (second stream-open) re-sends `start{ROOT}` and yields the same `rootId` with no duplicate root, no legacy `ModuleSessionStarted`/FGS side-effect.
- Starting a breath child with no device still creates a child on the server, independent of `rootId` (root open is not gated on biodata).
