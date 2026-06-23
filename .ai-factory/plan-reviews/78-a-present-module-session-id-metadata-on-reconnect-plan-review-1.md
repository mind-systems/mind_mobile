# Plan Review: A — Present `module-session-id` metadata on reconnect

**Plan:** `78-a-present-module-session-id-metadata-on-reconnect.md`
**Files verified:** 4 (target + 3 references)
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every concrete claim in the plan was checked against the actual source:

| Claim | Status |
|-------|--------|
| Import block is rxdart/fixnum/proto only, needs `CallOptions` | ✅ Confirmed (`ModuleStateChannel.dart:1-13`). `CallOptions` not currently imported. |
| `trackActivity` bare call at `:74` | ✅ Confirmed — `_moduleStateService.trackActivity(_sessionSink!.stream)`. |
| `_openSessionStream` spans `:71-105` | ✅ Confirmed. |
| `moduleSessionId` is `String?` | ✅ Confirmed (`ModuleState.dart:4`). Null-check before `isNotEmpty` is required. |
| Generated client accepts `{CallOptions? options}` | ✅ Confirmed (`module_state.pbgrpc.dart:35-40`). |
| `currentState` survives reconnect (`_closeSessionStream` does not reset `_state`) | ✅ Confirmed (`:107-112` touch only `_sessionSub`/`_sessionSink`). |
| `ModuleStateStatus.active` guard is valid | ✅ Confirmed — enum is `{ idle, active }` (`ModuleState.dart:1`). |

## Context Gates

- **Architecture:** No boundary violation. `ModuleStateChannel` is infrastructure under `lib/Core/Grpc/`; the change stays transport-level and does not touch module/domain boundaries. WARN: none.
- **Rules (`RULES.md`):** No applicable rule violated — the rules concern Module Services / App.dart wiring / constructor injection, none of which this change affects. WARN: none.
- **Roadmap:** Plan explicitly links to the milestone chain (precondition for milestone C, `154-handle-abandonment-confirmation`). Linkage present. WARN: none.

## Critical Issues

None.

## Observations (non-blocking)

1. **Metadata merges correctly with auth — verified.** `GrpcAuthInterceptor` attaches the JWT via `options.mergedWith(CallOptions(providers: [_addAuthMetadata]))` (`GrpcAuthInterceptor.dart:39,54`), receiving the per-call `CallOptions` we now pass. The `module-session-id` metadata and `authorization` header coexist with no clobbering. The plan's approach is compatible with the existing interceptor pipeline.

2. **Metadata key is gRPC-valid.** `module-session-id` is all-lowercase with hyphens — a valid gRPC ASCII metadata key (uppercase keys would be rejected at runtime). No issue.

3. **Import choice is fine.** The plan imports `package:grpc/grpc.dart`, which re-exports `CallOptions`. The generated stubs use `package:grpc/service_api.dart`, but `grpc.dart` is the conventional public surface and exposes the same `CallOptions` type — no type mismatch. No unprefixed name conflict is expected in this file (the proto import is prefixed `as proto`). Minor: if the implementer prefers consistency with generated code they could import `service_api.dart`, but `grpc.dart` is the more common app-side choice and is correct.

4. **Guard semantics are sound.** On COMPLETED/INTERRUPTED/ABANDONED the state resets to `initial()` (`:140-145`), so `status` is no longer `active` and no stale id is sent. On a non-terminal disconnect the `active` state with its `moduleSessionId` survives, so the reconnect correctly carries the live id. The `null && isNotEmpty` double-guard prevents both a null deref and an empty-string placeholder, satisfying the plan's own "never synthesize a placeholder" guard.

5. **Scope discipline is good.** The plan correctly leaves `_backoffConfirmed`, `onError`, and `onDone` untouched, and adds no proto change (metadata is transport-level). This is the minimal correct surface for the milestone-C precondition.

## Positive Notes

- File paths, line ranges, and the generated API signature were all accurate against the current tree — no drift.
- The null/empty handling caveat and the "state survives reconnect" reasoning are both explicitly called out and verified correct, removing the two most likely implementation traps.
- Two-task decomposition with an explicit dependency is appropriately granular for a ~6-line change.

PLAN_REVIEW_PASS
