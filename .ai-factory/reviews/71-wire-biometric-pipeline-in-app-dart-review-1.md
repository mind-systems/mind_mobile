# Code Review: Wire biometric pipeline in `App.dart` (#71)

## Scope

Reviewed the staged diff against `HEAD`:

- `lib/Core/App.dart` — three imports added, three `final` fields, three `required` ctor params, eight initializer lines inside `initialize()`, three values passed into `App._(...)`.
- `lib/Core/Grpc/GrpcClient.dart` — one import, one `late final` service-client getter.

The two plan/plan-review markdown files are documentation only and ignored for code-correctness purposes.

## Findings

### Correctness

- **Initializer ordering against the spec.** Spec says "after the existing BCI block (`bciDeviceManager`/`bciNotifier`) but before `App.shared` is constructed." Implementation puts the block right after `moduleStateChannel = ...` (line 185 → 186) — which is later than "after BCI block" but is the earliest valid location because `BiometricStreamClient` needs `moduleStateChannel.events`. This is correctly justified in the plan and matches the constraint that `App.shared` is still ahead. ✅
- **Same `bciProvider` for all five `register*` calls.** `NeiryBciProvider` declares `implements IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource` (line 33 of `lib/Bci/NeiryBciProvider.dart`). Passing one instance to all five registrations is valid. ✅
- **Late subscriber to a non-replaying `PublishSubject`.** `BiometricStreamClient` is constructed at App.dart:192, two lines after `moduleStateChannel = ...` at line 185. `ModuleStateChannel._events` is a `PublishSubject<ModuleStateEvent>`, which does NOT replay (`ModuleStateChannel.dart:21`). Events are only emitted from `_processProtoEvent`, which fires asynchronously when the `trackActivity` gRPC stream delivers responses, gated by `_connectionManager.connectionState.listen(...)`. No synchronous emission paths exist between line 185 and line 192 → no events can be missed. ✅
- **Liveness / GC.** `BiometricBatcher` owns an internal `StreamSubscription<BioSample>`, which by itself does not keep the batcher alive once `initialize()` returns. Storing `biometricBatcher` (and the other two) as `App` fields keeps the chain reachable through `App.shared`. Done correctly. ✅
- **Register-before-subscribe invariant.** All five `register*` calls happen on lines 187–191, before `BiometricBatcher(...)` is constructed on line 193 (whose constructor calls `router.samples.listen(...)`, materializing the lazy `_merged`). Cache invariant respected. ✅
- **Broadcast stream safety.** `NeiryBciProvider` uses `.broadcast()` controllers (already verified in prior milestone), so the router's subscriptions can coexist with `BciDeviceManager`'s existing subscriptions to `cardioStream`/`nfbStream`/`emotionsStream`. Multiple-subscriber compatibility is preserved. ✅
- **Buffer drain when no session is active.** While no module session is running, the batcher still buffers samples and calls `client.sendBatch(...)` on the 250 ms/25-sample boundary; `sendBatch` silently drops them when `_currentSessionId == null`. Buffer therefore never grows unboundedly. ✅
- **Sample rate / batch budget.** At expected source rates (cardio ~1 Hz, RR ~1 Hz, NFB few Hz, emotions ~1 Hz, motion ~25 Hz from MEMSClassifier batches), a 250 ms window comfortably fits under the 25-sample size threshold in steady state, with size-flush kicking in when MEMS batches arrive. No reachable pathology in the chosen constants. ✅

### Style

- All eight new initializer lines (186–193) are single-line statements with no trailing commas on the ctor call args — complies with the file-header style banner. ✅
- The `App._(...)` block (lines 200–225) uses trailing commas, matching existing style. ✅
- Import placement: `lib/Biometrics/*` lines fall between `lib/Bci/*` and `lib/McpModule/*` — alphabetically correct. ✅
- `GrpcClient.moduleBiometricStreamService` getter is placed between `deviceService` and `moduleStateService` — alphabetically correct (the existing list is not strictly sorted past that point, but the new entry preserves the prefix-alphabetical grouping). ✅

### Security

- No new untrusted-input paths; the wire encoder converts only locally-produced `BioSample` maps via `_mapToStruct`. No PII concerns introduced by wiring. ✅
- JWT/auth headers continue to flow through the existing `GrpcAuthInterceptor` injected into the channel — the new biometric stream client inherits this automatically because it consumes `grpcClient.moduleBiometricStreamService`, which is built on the same `_channel` with the same `_interceptors`. ✅

### Architecture / Rules

- **RULES.md rule 2** ("never add module-specific state/streams/triggers to App.dart"): the biometric pipeline is generic infrastructure equivalent to `moduleStateChannel`, `instructionStream`, `syncEngine` — none of these are module-specific. Not violated. ✅
- **RULES.md rule 3** (constructor injection): `BiometricStreamClient` receives `moduleStateEvents` via constructor; `BiometricBatcher` receives `router` and `client` via constructor; subscriptions are managed internally. Not violated. ✅
- **Module isolation contract**: neither `packages/breath_module/` nor `packages/bci_module/` is touched; nothing exposes `lib/Biometrics/` to them. Pipeline remains passive background plumbing as required by the spec. ✅

### Observations (non-blocking, no action required)

1. **Disposal not wired.** `BiometricStreamClient.dispose()` and `BiometricBatcher.dispose()` exist but are never called — `App` has no `dispose()` and process lifetime = pipeline lifetime. On detach, `GrpcClient.shutdown()` collapses the channel, which causes the bidi `streamData` call to error → `BiometricStreamClient.onError` → `_teardownSink()` cleans the sink. The `_lifecycleSub` to `moduleStateChannel.events` is left alive, but `moduleStateChannel._events.close()` is only called from `ModuleStateChannel.dispose()`, which is also never called. No leak in practice for app-singleton infrastructure, but if a future `App.dispose()` lands, both `biometricBatcher.dispose()` (first) and `biometricStreamClient.dispose()` (after) need to be wired. The spec acknowledges this.
2. **No event emitted by `ModuleStateChannel` on gRPC drop.** If the gRPC channel drops mid-session, `ModuleStateChannel._closeSessionStream()` runs but emits no `ModuleSessionEnded`/`Abandoned` — so `BiometricStreamClient._currentSessionId` stays set. When the batcher next calls `sendBatch`, `_ensureSinkOpen()` will try to reopen `streamData`; if the underlying channel hasn't reconnected yet, it errors and `_teardownSink` cleans up. When the channel reconnects, `ModuleStateChannel` reopens `trackActivity` and (typically) the server re-emits a `ModuleSessionStarted`, refreshing the id. Behavior is reasonable and self-recovering. Pre-existing component design, not something this wiring change introduces.
3. **`GrpcClient` getter ordering inside the existing list is slightly inconsistent** (`instructionStream` follows `moduleState` alphabetically out of order), but the new `moduleBiometricStreamService` insertion does not worsen the existing ordering and aligns with the obvious "module*" grouping.

REVIEW_PASS
