# Code Review — Session registry in `ModuleStateChannel` (root + N children)

**Scope:** `git diff HEAD` — `lib/Core/Grpc/SessionRegistry.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `test/Core/Grpc/session_registry_test.dart`, `test/Core/Grpc/module_state_channel_test.dart` (plan/artifact files ignored). All four code/test files read in full.
**Risk Level:** 🟢 Low — additive, behaviour-preserving, well-tested.
**Tests:** `flutter test` on both suites → **66/66 pass**, including the RED note-22 registry tests now green and the new channel-level routing tests.

## Verdict

No correctness, security, or runtime defects found in the changes. The implementation matches the plan and the note-14 spec:

- `SessionRegistry` is a clean in-memory routing layer (`Map<String, ModuleSession>`), no migration or persistence involved — nothing to break at the storage layer.
- The wiring in `ModuleStateChannel` is strictly **additive**: the legacy `_state` (`BehaviorSubject<ModuleState>`) and every `ModuleStateEvent` emission are untouched. Verified by the still-green legacy suite (Groups 1–10) and the explicit characterization test (Group 11, "legacy ModuleSessionStarted → ModuleSessionEnded sequence").
- `rootId` is derived (cached from `_computeRootId()` via the seeded `BehaviorSubject`), never a stored field; `childOfType` excludes the root and returns the sole child of a type — matches the contract.
- Reset parity is correct and consistent: `_reset()` (logout), `no_active_session`, and `ACTIVITY_STATUS_UNSPECIFIED` all pair the single-state reset with `_registry.clear()`, so idle-state never coexists with a non-null `rootId`. Terminal statuses call `removeTerminal(id)` (child only) — the root is never dropped by a child terminal.
- Disposal is guarded: `_isDisposed` short-circuits every mutator so a late `upsert`/`clear` cannot add to a closed subject; `dispose()` closes both subjects; the channel calls `_registry.dispose()` in its own `dispose()`. `clear()` (not `dispose()`) is used for resets, keeping the `final` registry reusable.
- The `unused_element` ignore on `_mapActivityTypeFromProto` was correctly dropped (the helper is now used).

## Non-blocking observations (verify against the live server contract; no code change required for this milestone)

**A. Per-frame log noise if the server omits `activity_type` on state frames.**
`_upsertRegistryEntry` → `_mapActivityTypeFromProto(ACTIVITY_TYPE_UNSPECIFIED)` returns `null` and logs `dropping unknown activity type` on **every** ACTIVE/RESUMED frame lacking `activity_type`. The test run shows this firing repeatedly (`[ModuleStateChannel] dropping unknown activity type: ACTIVITY_TYPE_UNSPECIFIED`) for legacy frames. The plan documents the load-bearing assumption that note-13's live proto guarantees `activity_type` on every state frame — this is fine **iff** that holds in production. If the live server does not yet populate it, this both (a) floods logs per-frame against the "Logging: minimal" intent and (b) leaves the registry silently empty for a live session. Action: confirm the deployed server populates `activity_type` on ACTIVE/RESUMED state frames before Phase 62 consumers read `rootId`; otherwise downgrade the log or gate it.

**B. Terminal-removal depends on the terminal frame carrying `moduleSessionId` — undocumented, symmetric to (A).**
`removeTerminal(event.moduleSessionId)` on COMPLETED/INTERRUPTED/ABANDONED removes by id. If a terminal frame arrives with an empty/absent `moduleSessionId` (some legacy terminal frames do — e.g. the ABANDONED path in existing tests uses a default `''`), `removeTerminal('')` is a no-op and a real child entry would leak in the registry until the next `clear()`. This is the terminal-side analogue of assumption (A) but is not called out in the plan or a code comment. Harmless in this milestone (registry not yet consumed), but it is exactly the silent-routing class this feature exists to prevent. Action: confirm the server addresses terminal frames with the child's `module_session_id`, and consider documenting this assumption alongside the `_upsertRegistryEntry` one.

Both items are server-contract assumptions, not defects in the diff, and are consistent with the milestone's "no behaviour change / additive substrate" scope. Neither blocks this change.

REVIEW_PASS
