# Plan: Session registry in `ModuleStateChannel` (root + N children)

## Context
Turn `ModuleStateChannel` into transport + a live **session registry**: fill the `SessionRegistry` routing bodies (map keyed by `module_session_id`, derived `rootId`/`childOfType`, change streams) and drive it from every incoming `StateEvent` — upsert by id, remove on terminal status, route by `activity_type` — so the client can *represent* a root + N concurrent children. Purely additive: the existing single `ModuleState` / `ModuleStateEvent` surface is preserved unchanged for incremental migration (Phase 62+ moves consumers onto the registry).

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Registry implementation (green the contract tests)

- [x] **Task 1: Fill `SessionRegistry` routing bodies + change streams**
  Files: `lib/Core/Grpc/SessionRegistry.dart`
  Replace the note-22 skeleton's `throw UnimplementedError()` bodies with a real routing layer backed by `final Map<String, ModuleSession> _sessions = {}` keyed by `module_session_id`:
  - `upsert(ModuleSession session)` → `_sessions[session.id] = session`, then notify (see streams below). Second frame for an existing id updates in place — no duplication.
  - `removeTerminal(String id)` → `_sessions.remove(id)`, then notify. Unconditional remove-by-id (the terminal-status decision stays in the caller — Task 2); removes only that entry, never touches others.
  - `void clear()` (new — not in the note-22 skeleton) → empties `_sessions` and fires the change/rootId notifications. Task 2 needs it to reset the whole registry on logout / no-active-session, which per-id `removeTerminal` cannot do (the map is private and unenumerable), and `dispose()` closes the subjects so it cannot be reused for a reset. Guard against post-`dispose` like the other mutators. A no-op (empty map) `clear()` should not spuriously emit a `rootIdChanges` value it was not already at (the `.distinct()` at the getter absorbs a redundant `null`→`null`).
  - `String? get rootId` → the `id` of the sole entry with `activityType == ActivityType.root`, else `null`. Two roots is a server bug — return the first match (do not throw).
  - `ModuleSession? childOfType(ActivityType type)` → the sole entry with `activityType == type && type != root`, else `null`. Never returns the root.
  - Change streams (use RxDart, already a dependency — mirror the `BehaviorSubject`/`PublishSubject` usage in `ModuleStateChannel.dart:22-23`): back `changes` with a broadcast subject fired after every `upsert`/`removeTerminal`; back `rootIdChanges` with a `BehaviorSubject<String?>.seeded(null)` fed the current `rootId` after each mutation, wrapped so it only emits on actual change (`.distinct()` at the getter). Late subscribers get the current `rootId`.
  - `dispose()` → close the subjects (was an empty no-op in the skeleton). Guard the notify path so a mutation after `dispose()` does not add to a closed subject.
  Keep the class pure Dart (no Flutter/Riverpod). This greens `test/Core/Grpc/session_registry_test.dart` (currently RED per note 22). Add one small GREEN test for `clear()` (upsert root + child → `clear()` → `rootId == null` and `childOfType` null for both) since the note-22 suite does not cover it. Remove the `// skeleton per note 22` framing from the doc comment where it no longer applies; keep the method contracts documented.

### Phase 2: Channel wiring (drive the registry from proto frames)

- [x] **Task 2: Own a `SessionRegistry` in `ModuleStateChannel` and feed it from `_processProtoEvent`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Make the channel own and drive the registry alongside the existing single-session state — additive, do NOT remove or alter the `_state` `BehaviorSubject<ModuleState>` (`:22`) or any `_events` `ModuleStateEvent` emission (`:132-157`). Existing behaviour must stay byte-identical.
  - Add `final SessionRegistry _registry = SessionRegistry();` and expose read-only accessors so downstream Phase 62–64 adapters can consume it: `String? get rootId => _registry.rootId;`, `ModuleSession? childOfType(ActivityType type) => _registry.childOfType(type);`, `Stream<String?> get rootIdChanges => _registry.rootIdChanges;`, `Stream<void> get registryChanges => _registry.changes;`. (Or expose `SessionRegistry get registry` — pick one; prefer the narrow delegating getters.)
  - **Load-bearing assumption (state it in a code comment):** every `ACTIVE`/`RESUMED` state frame from the server carries a populated `activity_type` (guaranteed by note 13's contract). This is load-bearing because nothing else backfills the registry in this milestone (reconnect rebuild is note 20) — if the server omitted `activity_type` on a live frame, the single-state would go active while the registry stayed silently empty (`rootId == null` for a live root), the exact silent failure this milestone prevents. Task 3 adds a characterization that a normal `ACTIVE` frame populates the registry, to catch a regression if the server ever stops sending it.
  - In `_processProtoEvent` (`:125-161`), after the existing single-state logic, drive the registry keyed by `event.moduleSessionId`:
    - Map the frame's `event.activityType` (proto) → app `ActivityType` via the already-present `_mapActivityTypeFromProto` helper (`:225-237`, currently `// ignore: unused_element` — drop that ignore once used). If it returns `null`, skip the registry upsert for that frame. Note the helper already `logPrint`s on an unknown type; under the assumption above this never fires on a legitimate `ACTIVE`/`RESUMED` frame, so it does not conflict with the "Logging: minimal" setting — it only fires on a genuinely-unknown/unset type, which is an anomaly worth logging.
    - On `RESUMED` / `ACTIVE`: `_registry.upsert(ModuleSession(id: event.moduleSessionId, activityType: <mapped>, status: ModuleStateStatus.active, isPaused: event.isPaused))`.
    - On `COMPLETED` / `INTERRUPTED` / `ABANDONED`: `_registry.removeTerminal(event.moduleSessionId)` — remove **only** that id; a child terminal must not drop the root (root is a separate entry).
    - On `ACTIVITY_STATUS_UNSPECIFIED`: the existing branch resets `_state` to `initial()` (`:155-157`) — for parity call `_registry.clear()` here too, so the single-state and the registry never diverge (idle state must not coexist with a non-null `rootId`). Do NOT rely on "no id to route" — an UNSPECIFIED frame can still carry a `moduleSessionId`, so an upsert-skip alone would leave stale entries; the full `clear()` is what matches the single-state reset.
    - Truly unhandled statuses (the trailing `else` `logPrint`, `:158-159`) and `DISCONNECTED` (already early-returned before this method, `:90`): leave the registry untouched — no single-state reset happens there either, so no divergence.
  - Clear the registry wherever the single state is reset: in `_reset()` (`:239-243`, the `GuestState` logout path) and on `sessionError == 'no_active_session'` (`:94-96`, which resets `_state` to `initial()`) — call `_registry.clear()` so a logged-out/no-session client has an empty registry (`rootId == null`).
  - In `dispose()` (`:247-253`), call `_registry.dispose()`.
  - Do NOT touch the `start()` single-session guard (`:166`), `_isPendingStart`/`_isPendingPause`, or command builders — the per-`activity_type` guard replacement is note 19 (later phase). This milestone adds representation only, no behaviour change.

### Phase 3: Channel-level routing tests

- [x] **Task 3: Add registry-population tests + characterization of the unchanged event surface** (depends on Task 2)
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Extend the existing suite (reuse its `_FakeModuleStateServiceClient` / `_FakeConnectionManager` fakes and the `StateResponse` frame-injection pattern) to cover the new — silently-failing — proto→registry wiring:
  - Feed a `ROOT` `ACTIVE` frame then a `BREATH` `ACTIVE` frame (each with its own `moduleSessionId` + `activityType`) → registry holds two distinct entries: `channel.rootId` == the root frame's id, `childOfType(ActivityType.breath)!.id` == the breath frame's id.
  - A child `COMPLETED` frame removes only the child (`childOfType(breath) == null`) while `rootId` still resolves the root (terminal-removal must not drop the root).
  - `isPaused` upsert-in-place: a second `ACTIVE` frame for the same child id with flipped `isPaused` updates the stored entry, not a duplicate (assert via `childOfType`).
  - **Positive characterization (regression guard for the load-bearing assumption):** a single normal breath `ACTIVE` frame with `activityType` set *does* populate the registry — `childOfType(breath)` resolves — so a future server regression that drops `activity_type` fails this test loudly instead of silently emptying the registry.
  - `UNSPECIFIED` clears the registry: with a root + child present, an `ACTIVITY_STATUS_UNSPECIFIED` frame drives both the single-state to idle **and** `rootId == null` (parity — no divergence).
  - Logout (`GuestState` on the auth stream) / no-active-session (`sessionError == 'no_active_session'`) clears the registry (`rootId == null`).
  - Characterization: a single-session breath-only flow (`ACTIVE` → `COMPLETED`) still emits the same `ModuleStateEvent` sequence (`ModuleSessionStarted` → `ModuleSessionEnded`) as before — proves the additive wiring did not perturb the legacy surface. If existing tests already assert this sequence, reference/keep them rather than duplicating.
  Do not test loud surfaces (proto decode, enum mapping — covered by note 13's compile).

## Verify
- `flutter analyze` clean (the `unused_element` ignore on `_mapActivityTypeFromProto` is now removed because it is used).
- `flutter test test/Core/Grpc/session_registry_test.dart` is GREEN (note 22's RED tests pass).
- `flutter test test/Core/Grpc/module_state_channel_test.dart` GREEN — registry routing asserted and the legacy `ModuleStateEvent` sequence unchanged.
