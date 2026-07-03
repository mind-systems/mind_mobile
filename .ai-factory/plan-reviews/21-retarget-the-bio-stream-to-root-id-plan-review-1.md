# Plan Review: Retarget the bio stream to `root.id`

Plan: `.ai-factory/plans/21-retarget-the-bio-stream-to-root-id.md`
Milestone: ROADMAP.md line 68 (Phase 63 — Continuous bio timeline)
Spec: `.ai-factory/notes/17-rootchild-bio-to-root.md`
Governing rollout: ROADMAP.md line 45 (Root/child realtime rollout, Phases 61–65)

## Code Review Summary

**Files reviewed:** `lib/Biometrics/BiometricStreamClient.dart`, `lib/Core/App.dart`, `lib/Core/Grpc/RootStateChannel.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/SessionRegistry.dart`, `lib/Core/Grpc/GrpcConnectionManager.dart`, both bio test files.
**Risk Level:** 🟡 Medium — the happy-path implementation is correct and greens the note-23 tests, but the design has a real reconnect regression that no test in scope covers.

### Context Gates
- **ARCHITECTURE.md:** No boundary violation. Both tasks stay inside the biometric pipeline and the existing DI wiring point. WARN-free.
- **RULES.md:** PASS. Rule 3 ("all dependencies injected via constructor; let the class manage its own subscription") is honored — `rootIdChanges` is a constructor param and the client owns `_rootIdSub`. Rule 2 ("no module-specific state in App.dart") is respected — Task 2 only threads an already-constructed stream (`rootStateChannel.rootIdChanges`) into the client at its existing construction site; this is infrastructure wiring, not module state.
- **ROADMAP.md:** Linked correctly. This is the unchecked milestone on line 68; its spec (note 17) and the RED-tests predecessor (line 67, note 23) are consistent with the plan. Line references in the plan (`:79`, `:94-101`, `:106-111`, `:121`, `:210-245`, App `:234`/`:225`) were all verified against the current code and are accurate.

### Critical Issues

**1. Root-sourced mode has no path to re-confirm `_sessionConfirmed` after a transient gRPC reconnect → bio silently stops flowing until re-auth.**

The plan reuses the existing `_sessionConfirmed` gate and explicitly leaves the disconnect path (`BiometricStreamClient.dart:79`) untouched, where `GrpcConnectionState.disconnected` sets `_sessionConfirmed = false`. In *legacy* mode that flag is re-armed on reconnect by `ModuleSessionResumed` (`_onLifecycleEvent`, `:98-101`). But Task 1 adds `if (_rootSourced) return;` at the top of `_onLifecycleEvent`, severing that re-confirmation path in production — and nothing replaces it. Trace the production reconnect:

1. Network blip → `GrpcConnectionManager.disconnect()` emits `disconnected` (`GrpcConnectionManager.dart:98`) → `BiometricStreamClient` sets `_sessionConfirmed = false` and tears down the sink (`:78-79`). `_currentSessionId` stays `'root-1'` (only cleared on `rootId == null`).
2. Reconnect → `connected` → `_ensureSinkOpen()` reopens the sink but does **not** touch `_sessionConfirmed`.
3. `ModuleStateChannel` never clears the registry on disconnect (`_closeSessionStream()` only, `:136-141`), so `SessionRegistry._rootIdChanges.value` is still `'root-1'`. On reconnect `RootStateChannel` re-sends `startRoot()`; the server's ROOT frame upserts the same id → `_notify()` → `_rootIdChanges.add('root-1')`. Because `rootIdChanges` is `.distinct()` (`SessionRegistry.dart:73`) and the root id is **idempotent** (same `root.id` per user), the redundant `'root-1' → 'root-1'` is **absorbed — no emission**. `_onRootIdChanged` is never called again.

Net result: after the *first* transient reconnect, `_sessionConfirmed` is stuck at `false`, the `sendBatch` gate (`:121`) drops every sample, and bio stops flowing for the rest of the session — recovering only across a full logout/login (which routes `_reset()` → `clear()` → a real `null` emission → a fresh `'root-1'`). This directly violates the milestone's own contract ("keep flowing… stopping only when the root is gone" — plan line 4, ROADMAP line 68). A transient reconnect is not "root gone." It is exactly the *silent* failure this phase exists to prevent (ROADMAP line 67), and no test in scope exercises disconnect→reconnect in root-sourced mode, so all four routing tests plus the golden master stay green while production regresses.

Note the interaction with the downstream reconnect milestone (ROADMAP line 79 / note 20): its reconcile flow rebuilds the registry from **per-child RESUMED frames** and re-learns `root.id` from the RootStateChannel ROOT re-open — but per note 45 that fan-out "carries no root frame," and even the ROOT re-open re-adds the *same* id, which `.distinct()` again suppresses. So the later milestone does not obviously fix this either (except on the `{abandoned}` global-reset path, which does pass through `null`). This gap should be closed here rather than assumed away downstream.

**Recommended resolution (pick one, then add a test):**
- Preferred: in root-sourced mode, re-confirm on the connection edge — when `rootIdChanges` has a non-null current id, treat `GrpcConnectionState.connected` as re-confirmation (e.g. set `_sessionConfirmed = true` on `connected` when `_rootSourced && _currentSessionId != null`). This keeps the "root known ⇒ bio confirmed" invariant across reconnects.
- Alternative: in root-sourced mode, do not clear `_sessionConfirmed` on disconnect (guard the `:79` clear with `if (!_rootSourced)`), since root liveness — not the transport — is the gate.
- Either way: add a routing test "bio keeps flowing under root.id across a disconnect/reconnect (no rootIdChanges re-emission)" — construct with `rootIdChanges`, emit `'root-1'`, drive `disconnected` then `connected` **without** re-emitting on `rootIdCtrl`, and assert a batch still flows under `'root-1'`. This is the missing coverage that let the gap through.

### Minor Notes

- **`final bool _rootSourced` must be assigned in the initializer list, not the constructor body.** The plan says "Add a `final bool _rootSourced` field set in the constructor to `rootIdChanges != null`." In Dart a `final` instance field must be initialized in the initializer list (`: _rootSourced = rootIdChanges != null, ...`) — it cannot be assigned in the body. Trivial, but worth pinning so the implementer doesn't reach for a `late final` or a non-final workaround.
- **`_onRootIdChanged` re-arming `_lastOpenAttempt = null` is correct and sufficient for the first-open case**, but note it does nothing for the reconnect case above precisely because the method isn't re-entered on reconnect. Not a separate bug — just confirming the cooldown re-arm is not a mitigation for Critical Issue 1.

### Positive Notes

- The switch-sourcing-mode design (`_rootSourced` gate on `_onLifecycleEvent`) cleanly preserves the golden-master legacy behavior while flipping production, and I verified all five legacy `biometric_stream_client_test.dart` groups remain unaffected (they construct without `rootIdChanges`, so `_rootSourced == false`).
- The `rootId == null` branch correctly clears `_currentSessionId`, `_sessionConfirmed`, `_lastOpenAttempt`, and `_replayRing` — and the plan's instruction to *not* tear down the sink there is right: routing test 3 injects `ready` on the still-open connection and asserts the ring drained nothing, which this satisfies.
- The decoupling guard (bio = root, phases = child; do not touch `BreathModuleStateChannel` / `ModuleInstructionStream`) is correct and well-stated; the phase path genuinely never touches `BiometricStreamClient`.
- Line references throughout the plan are accurate against the live code, and the `SESSION_NOT_FOUND`-is-already-swallowed claim checks out (`ModuleInstructionStream` logs the error frame without teardown).

### Verdict

One blocking correctness issue (reconnect re-confirmation gap) plus one trivial implementation note. Close Critical Issue 1 — with the accompanying reconnect test — before implementation.
