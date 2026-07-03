# Plan: Reconnect via `root.id` header + abandoned/reconcile handling

## Context
Turn the dormant reconnect/eviction resilience green: send `root.id` (not the last child) in the `module-session-id` reconnect header, classify stream closes into yield-vs-reconnect via the `ConnectionLifecycle` FSM, emit the already-wired `SessionTerminated(reason)` on whole-tree resets, and rebuild the registry by reconcile-by-arrival. This is the impl half of Phase 64's contract (notes 24/20), expressed on the notes 25/26 refactor substrate — no loose booleans.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Ground truth (post-refactor tree — pinned at plan time)

- **`lib/Core/Grpc/ModuleStateChannel.dart`** — the FSM chokepoint. Key sites:
  - `_openSessionStream` (`:109-155`): FSM `→ opening` at `:110`; header built from `currentState.moduleSessionId` at `:112-116`; `_sessionStreamOpened.add(null)` at `:154`.
  - `sessionError` branch (`:129-134`): currently only handles `no_active_session`.
  - `onError` (`:139-145`) and `onDone` (`:146-152`): both identical — `disconnect()` + `scheduleReconnect()` + `→ reconnecting`.
  - connected/disconnected handler (`:89-99`): `connected → _openSessionStream()`.
  - `_processProtoEvent` UNSPECIFIED branch (`:205-211`): clears registry + resets state, **emits no event**.
  - `_handleRootFrame` (`:244-253`): a root terminal only `removeTerminal`s the root's own entry (no cascade, no event).
  - `_upsertRegistryEntry` (`:226-235`); pending guards `_isPendingStart`/`_isPendingPause` (`:44-45`); `_reset` (`:346-352`).
  - `_transition` (`:54-57`) is the sole `_lifecycle` mutation point.
- **`lib/Core/Grpc/ConnectionLifecycle.dart`** — `yielded` is defined but dormant (no transition reaches it).
- **`lib/Core/Grpc/ModuleStateEvent.dart`** — `SessionTerminated(SessionTerminationReason {movedToAnotherDevice, abandoned, rootDeath})` exists; **no emitter yet**.
- **`lib/Core/Grpc/SessionRegistry.dart`** — `rootId` (computed from the ROOT entry), `childOfType`, `upsert`, `removeTerminal`, `clear`; no per-id enumeration exposed to the caller.
- **`lib/Core/Grpc/RootStateChannel.dart`** — sends `startRoot` on every `sessionStreamOpened` emission (so a reopen re-mints the root).
- **Consumers already wired** (dormant, waiting for the emitter): `BreathModuleStateChannel:53`, `MeditationModuleStateChannel:35`, `BiometricStreamClient:111`, `KeepAliveCoordinator:54`, `GlobalListeners:54-61` (reason→snackbar), `App.dart:322` (`sessionTerminatedStream`). ARB key `sessionMovedToAnotherDevice` already exists. **Do not touch these** — the emitter drives them.
- **Executable spec (must go green):** `test/Core/Grpc/reconnect_eviction_contract_test.dart` + `test/Core/Grpc/Support/reconnect_concurrency_harness.dart` (INV-1/2/3/4/5/6/7, SC-3/4/5/6). INV-7/SC-5/onError are GREEN-now guards — must not regress. INV-3 is `skip:`-gated on the not-yet-public `takeOverHere()`.
- **Test migration blast radius:** `test/Core/Grpc/module_state_channel_test.dart` Group 4 header assertions (`:449-451`, `:531-533` — asserted child ids `live-123`/`s1`) and the UNSPECIFIED emptiness assertion (`:814-815`, `received, isEmpty`).

## Tasks

### Phase 1: Header source → `root.id`

- [x] **Task 1: Source the `module-session-id` reconnect header from `root.id`**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_openSessionStream` (`:112-116`) replace the `currentState.moduleSessionId` header source with `_registry.rootId`. Read `rootId` into a local **at the very top of the method, before** any reconcile step (Task 5) drops the pre-reconnect root, so the pre-reconnect `root.id` still reaches the header. Keep the existing guard shape: attach `CallOptions(metadata: {'module-session-id': rootId})` only when `rootId != null && rootId.isNotEmpty`; otherwise pass `null` options. Do not send a child id ever (Guard: note 20 — "send `root.id` only when known").

- [x] **Task 2: Migrate the header-metadata assertions (one pass)** (depends on Task 1)
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Group 4 (`ModuleStateChannel — CallOptions metadata`, `:437-538`) activates sessions with a bare `moduleSessionId` and no `activityType`, so the registry stays empty and `rootId` is null under the new source. Rewrite the two positive assertions (`:449-451` `live-123`, `:531-533` `s1`) to first drive a **ROOT** `ACTIVE` frame (`activityType: proto.ActivityType.ROOT`, e.g. `root-1`) into the registry, then reconnect and assert `metadata['module-session-id'] == 'root-1'`. Keep the three null-options tests meaningful under the new rule ("null when no root known"): idle/empty/absent-root all yield `null` options. Do not add a child-id-in-header assertion — that is now explicitly wrong.

### Phase 2: Close-classification & yield latch (last-connect-wins)

- [x] **Task 3: Observe `CONNECTION_SUPERSEDED`, classify the close as yield-vs-reconnect, and reset the tree on yield** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Add a **per-stream transient** input to the close transition — a single field (e.g. `bool _supersededOnThisStream = false`) that is **reset to false whenever the FSM enters `opening`** (in `_openSessionStream`), so it is a transition guard, not a cross-handler latch. In the `sessionError` branch (`:129-134`), when `r.sessionError.code == 'CONNECTION_SUPERSEDED'` set the flag (do not reset state in the error branch — the close that follows drives the transition). In `onDone` (`:146-152`) branch on the flag:
  - flag set → transition `→ yielded`; perform the whole-tree reset via a new private helper `_resetWholeTree()` (`_registry.clear()`, `_state.add(ModuleState.initial())`, clear `_isPendingStart`/`_isPendingPause`) — introduced here and reused by Task 5's two reset sites — then emit `SessionTerminated(SessionTerminationReason.movedToAnotherDevice)`; close the stream; and **do NOT** call `disconnect()`/`scheduleReconnect()`. (Note 26 groups `movedToAnotherDevice` with `abandoned`/`rootDeath` as a whole-tree termination reason; note 20 §13/§37 — the takeover "starts fresh … do not expect the old children back". Resetting on yield — not deferring to takeover — makes the Task 7 reconcile snapshot at the takeover reopen empty, so `childOfType(breath)` is `null` immediately without waiting on the 3s window, which is what INV-3 asserts.)
  - flag clear (bare close) → unchanged path (`disconnect()` + `scheduleReconnect()` + `→ reconnecting`).
  Leave `onError` (`:139-145`) unchanged (transport drop always `→ reconnecting`). Greens INV-1/SC-4 and is the reset half of INV-3; keeps INV-1/SC-5 and the onError guard green. The directive is only "do not `disconnect()`/`scheduleReconnect()` on the yield branch" — the whole-tree reset is required.

- [x] **Task 4: Gate stream reopen on `yielded` (connected handler only); add `takeOverHere()`; clear yield on logout** (depends on Task 3)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Guard reopen in the **`connected` handler** (`:91-92`) only — `case connected: if (_lifecycle == ConnectionLifecycle.yielded) break; _openSessionStream();` — so `GrpcConnectionManager` reopens (connectivity / app-resume / auth) are inert while yielded (greens INV-2/SC-6). **Do NOT** place the guard at the top of `_openSessionStream`: `takeOverHere()` calls `_openSessionStream()` while `_lifecycle` is still `yielded`, so a guard there would self-block the takeover (INV-3's `expect(f.service.calls.length, callBaseline + 1)` at `:304` would fail). Add a public `void takeOverHere()` — **the** `yielded → opening` transition, the one caller allowed to leave `yielded`: no-op unless currently `yielded`; otherwise clear `_supersededOnThisStream` and call `_openSessionStream()` directly (bypassing the connected-handler guard), which re-fires `sessionStreamOpened` → `RootStateChannel` re-mints a clean root, no children. Ensure `_reset` (`:346-352`, logout) already transitions to `disconnected` (it does) and also clears `_supersededOnThisStream`, so an evicted-then-logged-out device reconnects normally on next login.

### Phase 3: Whole-tree reset → `SessionTerminated` emitters

- [x] **Task 5: Emit `SessionTerminated(abandoned)` on the `{abandoned}` UNSPECIFIED frame and `SessionTerminated(rootDeath)` on a root terminal** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In the UNSPECIFIED branch (`:205-211`): after clearing the registry and resetting state, also clear the command pending guards (`_isPendingStart = false; _isPendingPause = false;`) and emit `_events.add(SessionTerminated(SessionTerminationReason.abandoned))`. In `_handleRootFrame` (`:248-252`): on a root-level `COMPLETED`/`INTERRUPTED`/`ABANDONED`, replace the single-entry `removeTerminal` with a whole-tree reset — `_registry.clear()` + reset single-state to `ModuleState.initial()` + clear pending guards + emit `SessionTerminated(SessionTerminationReason.rootDeath)`. Reset must be **idempotent** (a second reset lands cleanly) and land **before** any freshly-minted root repopulates the registry (server sequencing per note 20 §Sequencing; adopt the new root idempotently after). Greens INV-6; wakes the already-wired adapter/bio/keep-alive/snackbar consumers. **Factor the three-line reset sequence** (`_registry.clear()` + `_state.add(ModuleState.initial())` + clear both pending guards) **into one private helper** (e.g. `_resetWholeTree()`) and call it from all three whole-tree reset sites — the UNSPECIFIED branch and `_handleRootFrame` here plus the SUPERSEDED yield branch (Task 3) — so the reset never drifts between reasons. Task 3 (Commit 2) introduces the helper inline; this task reuses it. Each site emits its own `SessionTerminated(reason)` after calling the helper.

- [x] **Task 6: Migrate the UNSPECIFIED-emits-nothing assertion** (depends on Task 5)
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  The Group 6 test `should reset to initial and clear pending-start on an ACTIVITY_STATUS_UNSPECIFIED frame` (`:800-819`) asserts `received, isEmpty` at `:815`. Under Task 5 an UNSPECIFIED frame now emits `SessionTerminated(abandoned)`. Change the assertion to expect exactly one `SessionTerminated` whose `reason == SessionTerminationReason.abandoned`; keep the state-resets-to-idle assertion (`:814`). Audit the same file for any other reader of "UNSPECIFIED emits nothing" and migrate in this pass — no piecemeal follow-ups.

### Phase 4: Reconcile-by-arrival

- [x] **Task 7: Rebuild the registry by reconcile-by-arrival on reopen** (depends on Task 1, Task 4)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/SessionRegistry.dart`
  On stream reopen in `_openSessionStream` (after reading `rootId` for the header in Task 1, and only when actually opening — i.e. not while yielded): (1) snapshot the currently-cached **child** ids; (2) drop the pre-reconnect **root** entry immediately so `rootId` is `null` until the note-15 ROOT re-open lands (greens INV-4 — root is never derived from the child fan-out); (3) arm a **3s** settling window (`Timer`); (4) as frames arrive, record each real child arrival (hook `_upsertRegistryEntry` / the child-status path to add the id to an "arrived" set); (5) when the window closes, evict every snapshotted child id that did **not** re-arrive (greens INV-5/SC-3 — a silent cached child is treated as gone), then clear the reconcile bookkeeping. Tolerate one collapsed resume frame or many. Add the minimal `SessionRegistry` surface needed to snapshot/enumerate child ids and to drop only the root entry (e.g. `childIds`/`removeById`), keeping the terminal-status decision in the caller. `childIds` must **exclude** the `ActivityType.root` entry (mirror the `childOfType` guard at `SessionRegistry.dart:62-68`) so a stale root id never lands in the snapshot; `removeById` must call `_notify()` so `rootId` (a `BehaviorSubject.value`) updates synchronously — Task 1's read-before-drop relies on the root drop being observable the moment reconcile runs. Cancel the settling `Timer` on the next reopen and in `dispose()` (`:356-364`) — INV-4/INV-6 dispose without elapsing the window, so a pending `Timer` left uncancelled makes `fakeAsync` throw. The timer is armed on **every** `_openSessionStream` (including first connect, where the snapshot is empty and eviction is a no-op). Trust `is_paused` from RESUMED frames — do not re-derive (INV-7 guard stays green). The settling window is the reconcile surface note 19 (start-race) will anchor to — expose it as a clean seam, but implement no pending-start retry here (out of scope).

### Phase 5: Green the executable spec

- [x] **Task 8: Un-skip INV-3 and run the full reconnect/eviction + channel suites** (depends on Tasks 3, 4, 5, 7)
  Files: `test/Core/Grpc/reconnect_eviction_contract_test.dart`
  Remove the `skip:` on the INV-3 `takeOverHere()` test (`:317`) and replace the `(f.channel as dynamic).takeOverHere()` dynamic dispatch (`:301`) with a direct static call now that the method is public (Task 4). Run `flutter test test/Core/Grpc/` and confirm: all INV-1..INV-7 / SC-3..SC-6 pass, the GREEN-now guards (INV-7, SC-5, onError, INV-12 ceiling) stay green, and `module_state_channel_test.dart` passes with the migrated assertions. Do not weaken any guard test to force a pass — a red guard means a regression in Tasks 1–7.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Source reconnect header from root.id and migrate header assertions"
- **Commit 2** (after tasks 3-4): "Classify SUPERSEDED close as yield, gate reopen, add takeOverHere"
- **Commit 3** (after tasks 5-6): "Emit SessionTerminated on whole-tree resets and migrate assertion"
- **Commit 4** (after tasks 7-8): "Rebuild registry by reconcile-by-arrival and green the contract suite"
