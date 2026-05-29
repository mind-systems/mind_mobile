# Plan Review: Wire biometric pipeline in `App.dart` (#71)

## Code Review Summary

**Plan File:** `.ai-factory/plans/71-wire-biometric-pipeline-in-app-dart.md`
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md**: Not deeply audited — the plan is pure DI plumbing inside
  `App.initialize()` and does not touch architectural boundaries (no module
  imports `lib/Biometrics/`, no module Service touched). No conflicts surfaced.
- **RULES.md**:
  - Rule 1 (stateless module Services): N/A — the touched code is not a module
    Service.
  - Rule 2 (no module-specific state in `App.dart`): respected. `BioStreamRouter`,
    `BiometricStreamClient`, `BiometricBatcher` are infrastructure plumbing
    (gRPC sink + multiplexer), equivalent to `moduleStateChannel` /
    `syncEngine` / `instructionStream` already wired here.
  - Rule 3 (constructor injection): respected. `BiometricStreamClient` accepts
    `moduleStateEvents` and `grpcStub` via constructor; `BiometricBatcher`
    accepts `router` and `client` via constructor. No outside subscription
    wiring.
- **ROADMAP.md**: Phase 21 milestones 6–8 are already shipped (router/client/batcher);
  this plan is the final wiring step. Linkage looks correct.

### Verification of Plan Claims

Every concrete claim in "Pre-flight findings" was checked against the codebase:

| Claim | Verified |
|---|---|
| `BioStreamRouter`, `BiometricStreamClient`, `BiometricBatcher` already exist | ✅ `lib/Biometrics/{BioStreamRouter,BiometricStreamClient,BiometricBatcher}.dart` present |
| `NeiryBciProvider` implements all five capability mixins | ✅ Line 33 of `lib/Bci/NeiryBciProvider.dart` confirms `IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource` |
| Generated stub class name `ModuleBiometricStreamServiceClient` | ✅ `lib/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart` line 24 |
| `GrpcClient` has 9 existing service getters and no biometric one | ✅ Lines 31–39, currently 9 services, no biometric stub exposed |
| `ModuleStateChannel.events` is `Stream<ModuleStateEvent>` | ✅ `ModuleStateChannel.dart:24` |
| Ordering: `moduleStateChannel` constructed at line 176, BCI block ends at line 159, `App._(...)` begins at line 183 | ✅ Exact line numbers match current file |
| `bciProvider` local exists at line 151 | ✅ `final bciProvider = NeiryBciProvider();` |
| `NeiryBciProvider` streams are `.broadcast()` so the router subscribing to them in addition to `BciDeviceManager`'s existing subscriptions is safe | ✅ Lines 42–53 of `NeiryBciProvider.dart` all use `StreamController.broadcast()` |
| Style rule (single-line initializers, no trailing commas) | ✅ Confirmed at top of `App.dart` |

### Critical Issues

None.

### Minor Notes / Suggestions

1. **Task 5 description slightly miscounts statements.** The body lists "Three
   statements plus five `register*` calls" but the snippet is actually 8 lines:
   one `bioStreamRouter` declaration, 5 `register*` calls, then `biometricStreamClient`
   and `biometricBatcher` declarations. Cosmetic — the code block is correct.

2. **No dispose path is wired for `BiometricStreamClient` / `BiometricBatcher`.**
   Both expose `dispose()` (cancel subs, close sink). `App` has no `dispose()`
   method today and the gRPC channel is shut down on `appLifecycleService.onDetach`
   via `GrpcClient.shutdown()` — at which point in-flight `_sink.add` calls in
   `BiometricStreamClient` will fail and the client logs + tears down. This is
   acceptable for app-singleton infrastructure, but worth flagging: if a future
   refactor adds an `App.dispose()` or hot-restart cleanup path, these two also
   need to be torn down. Not a blocker for the current milestone.

3. **Holding the three values as `App` fields is required for liveness.** Without
   `final biometricBatcher`, the batcher would have no references after
   `initialize()` returns and Dart would GC it (its `StreamSubscription` is held
   internally, but `BiometricBatcher` itself is the only owner of that
   subscription). Storing it on `App.shared` is the correct call — worth noting
   this is the *reason* for the fields, since the plan's Task 7 says "nothing on
   the UI surface reads ...". The plan is correct, just under-explains the
   motivation.

4. **Router's "register before first read" invariant is honored**, but the order
   in the snippet matters: all five `register*` calls happen before
   `BiometricBatcher(...)` is constructed, and `BiometricBatcher` subscribes to
   `router.samples` inside its constructor (line 30 of `BiometricBatcher.dart`).
   Plan code respects this. Anyone editing the block later must preserve this
   order — consider a short comment in the inserted block to lock it in, but
   not required.

5. **`GrpcClient` getter naming.** Plan says place it "between `moduleStateService`
   and `instructionStreamService` to keep alphabetical-ish grouping". Current
   order is in fact strictly alphabetical (auth, bciDevices, breathSession,
   device, moduleState, instructionStream — wait, this last pair breaks
   alphabet). Looking again: the existing order is auth → bciDevices →
   breathSession → device → moduleState → instructionStream → stats → sync →
   user. That's *not* alphabetical (`instructionStream` < `moduleState`). So
   the existing list is loosely grouped, not strictly sorted, and placing
   `moduleBiometricStream` adjacent to `moduleState` is fine. Non-blocking.

### Positive Notes

- The plan correctly identifies the ordering constraint (BiometricStreamClient
  needs `moduleStateChannel.events`, which is constructed *after* the BCI block)
  and places the pipeline block at the right line.
- The plan correctly recognizes that the same `bciProvider` instance can be
  passed to all five `register*` calls because `NeiryBciProvider` implements
  every capability mixin.
- The plan correctly anticipates the Style Rule banner at the top of `App.dart`
  and adjusts the trailing-comma style by location (single-line initializers
  vs. the `App._(...)` multi-line call block).
- The plan explicitly checks the rule against putting "module-specific state in
  App.dart" (RULES.md rule 2) and correctly classifies the pipeline as
  infrastructure, not module-specific.
- Task graph is correctly ordered with explicit `depends on Task N` annotations.
- Task 7 includes a sanity check that no package imports `lib/Biometrics/` —
  preserves the module isolation contract.

### Verdict

The plan is concrete, line-accurate, and architecturally sound. All pre-flight
findings were verified against the current codebase and match. No critical
issues; the only items above are documentation-quality nitpicks.

PLAN_REVIEW_PASS
