# Plan: Update LiveSessionCoordinator.dart in packages/breath_module/

## Context

The ROADMAP item (3.5) says: "replace calls to `ILiveSocketService` methods with equivalent gRPC stream sends **if interface changes**." After investigation, `LiveBreathSessionCoordinator` does not reference `ILiveSocketService` at all — it depends on `ILiveBreathSessionService` and `IBreathTelemetryService`, both of which are module-boundary interfaces. These interfaces are unchanged; the gRPC migration happened entirely underneath them (via `LiveBreathSessionService` → `LiveBreathSessionNotifier` → `LiveSessionGrpcService`). No method signatures need updating.

One defensive fix is needed: `reset()` does not clear `_liveSessionId`, so after a session restart the coordinator may briefly send telemetry with a stale server-assigned ID until the new `session:state` response arrives. Under gRPC (where reconnects may invalidate old sessions), this should be explicitly cleared.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix and verify

- [x] **Task 1: Reset `_liveSessionId` in `reset()`**
  Files: `packages/breath_module/lib/src/BreathSession/LiveBreathSessionCoordinator.dart`
  Add `_liveSessionId = null;` to the `reset()` method, alongside the existing `_pendingTelemetry = null` and flag resets. This ensures that after a session restart, telemetry is not sent with a stale server-assigned session ID — instead it is queued in `_pendingTelemetry` until the new `liveSessionId` arrives via `sessionStateStream`, which is the same path used on first start.

- [x] **Task 2: Mark ROADMAP item 3.5 as complete**
  Files: `mind_mobile/.ai-factory/ROADMAP.md`
  Check the box for "Update `LiveSessionCoordinator.dart` in `packages/breath_module/`" in section 3.5. All four items in 3.5 are now complete.
