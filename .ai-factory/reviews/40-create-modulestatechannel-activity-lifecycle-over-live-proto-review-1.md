## Code Review — ModuleStateChannel + GrpcConnectionManager refactor

**Plan:** `40-create-modulestatechannel-activity-lifecycle-over-live-proto.md`
**Files reviewed:** 6 changed/new files + 8 consumer/dependency files

---

### Verified against plan

All five tasks are implemented correctly:

1. **ModuleState/ModuleStateEvent types** — match plan spec. `const` constructor, `factory initial()`, sealed event hierarchy with correct subclasses.
2. **GrpcConnectionManager pure state machine** — callbacks removed, `confirmConnected()` added, `_resumeSubscription` updated to use `currentState != connected`, `_isConnecting` lifecycle explicit with assignment after emitting `connected`.
3. **ModuleStateChannel** — state/events subjects, backward-compat `rawSessionEvents`, connection state subscription, bidi stream lifecycle, proto→typed mapping, pending guards, auth reset, dispose. All present and correct.
4. **LiveSessionGrpcService delegation** — constructor updated, live stream code removed, connection state subscription drives telemetry, backward-compat `ILiveSessionService` delegation via `rawSessionEvents.map()`, `dispose()` includes `_telemetryStateController`.
5. **App.dart wiring** — fields added, initialization order correct (manager → channel → service), imports present.

### Correctness checks

- **Proto enum mapping:** All `SessionStatus` values match `live.pbenum.dart`. `DISCONNECTED` correctly filtered before `rawSessionEvents`. `SESSION_STATUS_UNSPECIFIED` handled as no-active-session sentinel in channel, passes through backward-compat bridge as `'unknown'` (same behavior as pre-refactor).
- **Backward-compat bridge:** `_mapSessionStatus` output matches what `LiveBreathSessionNotifier._onSessionState` expects. `'active'`, `'resumed'`, `'completed'`, `'abandoned'`, `'interrupted'` all map correctly. Dead `'ended'` string path in notifier is never hit (correct).
- **Bootstrap ordering:** `BehaviorSubject` replay is correct. Manager connects during constructor if authenticated → channel replays `connected` and opens live stream → service replays `connected` and opens telemetry stream. Sequential creation order in `App.initialize()` ensures proper cascade.
- **Re-entrancy safety:** `_closeLiveStream()` is idempotent via null guards. Error handler sequence (`_closeLiveStream()` → `disconnect()` → listener fires `_closeLiveStream()` again) is safe.
- **Backoff semantics:** `confirmConnected()` is called after stream subscription setup, matching the old design where `_resetBackoff()` ran after `_onConnect()` returned. Both channel and service call it independently; double-call is harmless.
- **ILiveSessionService contract:** All 6 interface members delegated correctly. `sessionStateEvents` getter returns a mapped broadcast stream — accessed once by `LiveBreathSessionNotifier` constructor, held as subscription.
- **Consumer impact:** `BreathTelemetryService`, `LiveBreathSessionNotifier`, `LiveBreathSessionService`, `HomeService` — none reference removed APIs. All continue to work through existing interfaces.
- **SyncGrpcListener:** Independent, manages its own auth/connection lifecycle. Not affected by this change.

### Minor notes (non-blocking)

1. **`_openTelemetryStream()` is still `async` but contains no `await`.** The `async` is vestigial from the old design where the method was awaited by `Future.wait`. Now it's called fire-and-forget from a synchronous listener. The method body executes synchronously in practice, but if it were to throw, the exception would become an unhandled Future error instead of propagating. Consider removing `async` for consistency with `ModuleStateChannel._openLiveStream()` (which is correctly synchronous). Not a bug — gRPC stub methods don't throw synchronously.

2. **No defensive guard against double-open in `_openLiveStream()` / `_openTelemetryStream()`.** If called while a subscription is already active, old handles would leak. The state machine prevents this in practice (`connected` only fires after `disconnected` has cleaned up), but adding `_closeLiveStream()` at the top of `_openLiveStream()` (and similar for telemetry) would be a belt-and-suspenders guard. Not a bug under current flow.

---

REVIEW_PASS
