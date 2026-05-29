# Plan: Wire biometric pipeline in `App.dart`

## Context
Wire the three already-implemented biometric pipeline classes (`BioStreamRouter`, `BiometricStreamClient`, `BiometricBatcher`) into `App.initialize()` so BCI samples flow to the API during active module sessions. This milestone is pure plumbing — no new classes, no UI changes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Pre-flight findings

- `lib/Biometrics/{BioStreamRouter,BiometricStreamClient,BiometricBatcher}.dart` already exist (Phase 21 milestones 6-8).
- `NeiryBciProvider` already `implements IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource` (line 33 of `lib/Bci/NeiryBciProvider.dart`), so a single `bciProvider` instance can be passed to all five `register*Source` calls.
- The generated gRPC stub class is `ModuleBiometricStreamServiceClient` (`lib/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart`).
- `GrpcClient` (`lib/Core/Grpc/GrpcClient.dart`) does **not yet expose** a getter for that stub — it must be added (one `late final` line, mirroring the existing nine service getters).
- `ModuleStateChannel.events` already exists as `Stream<ModuleStateEvent>`.
- **Ordering constraint:** in current `App.initialize()`, the BCI block ends at line 159, but `moduleStateChannel` is not created until line 176. Since `BiometricStreamClient` requires `moduleStateChannel.events` in its constructor, the pipeline block must be placed **after** line 176 (after `moduleStateChannel = ...`), not directly after the BCI block. The spec's "after BCI block, before `App.shared`" constraint is satisfied so long as we are between line 159 and line 183.
- Style rule at top of `App.dart`: every initializer must be a single-line statement, no trailing commas, parameters added in the middle.
- `RULES.md` rule 2 (no module-specific state/streams/triggers in `App.dart`) is **not violated** — the biometric pipeline is infrastructure plumbing (gRPC sink + router + batcher), not module-specific concern. The pipeline is owned by `App` exactly like `moduleStateChannel`, `instructionStream`, `syncEngine`.
- `RULES.md` rule 3 (constructor injection): respected — `BiometricStreamClient` receives `moduleStateEvents` via constructor; `BiometricBatcher` receives `router` and `client` via constructor. No outside-wiring of subscriptions.

## Tasks

### Phase 1: Expose the gRPC stub

- [x] **Task 1: Add `moduleBiometricStreamService` getter to `GrpcClient`**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Add `import 'package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart';` alongside the other generated imports. Add one `late final` field next to the existing service getters (between `moduleStateService` and `instructionStreamService` to keep alphabetical-ish grouping): `late final moduleBiometricStreamService = ModuleBiometricStreamServiceClient(_channel, interceptors: _interceptors);`. No other changes.

### Phase 2: Wire the pipeline in `App.dart`

- [x] **Task 2: Add imports for the three biometric classes** (depends on Task 1)
  Files: `lib/Core/App.dart`
  Add three imports in the existing alphabetically-sorted block (next to other `package:mind/Biometrics/` paths if any, otherwise grouped sensibly): `import 'package:mind/Biometrics/BioStreamRouter.dart';`, `import 'package:mind/Biometrics/BiometricStreamClient.dart';`, `import 'package:mind/Biometrics/BiometricBatcher.dart';`.

- [x] **Task 3: Add three `final` fields on `App`** (depends on Task 2)
  Files: `lib/Core/App.dart`
  In the `App` class field block (after line 84, `final BciNotifier bciNotifier;`, grouping with related infrastructure), add three fields: `final BioStreamRouter bioStreamRouter;`, `final BiometricStreamClient biometricStreamClient;`, `final BiometricBatcher biometricBatcher;`. Order them together so they form a single readable block.

- [x] **Task 4: Add the three fields as `required` named parameters in `App._` constructor** (depends on Task 3)
  Files: `lib/Core/App.dart`
  In `App._({...})` (lines 89-111), add `required this.bioStreamRouter,`, `required this.biometricStreamClient,`, `required this.biometricBatcher,` to the parameter list, kept together in the same order as the field declarations.

- [x] **Task 5: Construct the pipeline inside `App.initialize()`** (depends on Task 4)
  Files: `lib/Core/App.dart`
  Insert the pipeline block **immediately after** the `moduleStateChannel` line (currently line 176, `final moduleStateChannel = ModuleStateChannel(...)`) and **before** `final instructionStream = ...` on line 177. Use the single-line, no-trailing-comma style mandated by the file header comment. Three statements plus five `register*` calls:
  ```dart
  final bioStreamRouter = BioStreamRouter();
  bioStreamRouter.registerHeartRateSource(bciProvider);
  bioStreamRouter.registerRrIntervalSource(bciProvider);
  bioStreamRouter.registerEegBandsSource(bciProvider);
  bioStreamRouter.registerEmotionsSource(bciProvider);
  bioStreamRouter.registerMotionSource(bciProvider);
  final biometricStreamClient = BiometricStreamClient(grpcStub: grpcClient.moduleBiometricStreamService, moduleStateEvents: moduleStateChannel.events);
  final biometricBatcher = BiometricBatcher(router: bioStreamRouter, client: biometricStreamClient);
  ```
  The `bciProvider` local exists from line 151. The same `NeiryBciProvider` instance is passed to all five `register*` calls — it implements every capability mixin and the router preserves source identity on every sample via the `source` tag.

- [x] **Task 6: Pass the three values into the `App._(...)` call** (depends on Task 5)
  Files: `lib/Core/App.dart`
  In the `shared = App._(...)` block (lines 183-205), add three lines next to the related infrastructure fields (grouped after `bciNotifier: bciNotifier,`): `bioStreamRouter: bioStreamRouter,`, `biometricStreamClient: biometricStreamClient,`, `biometricBatcher: biometricBatcher,`. Trailing commas here are normal (multi-line block, not initializer style), matching the existing pattern in this block.

### Phase 3: Sanity check

- [x] **Task 7: Verify the project compiles** (depends on Task 6)
  Files: none (build only)
  Run `flutter pub get` then `flutter analyze` from `mind_mobile/`. Fix any import order / unused import warnings introduced. No functional changes — the pipeline is dormant until a module session actually starts; nothing on the UI surface reads `App.shared.bioStreamRouter` / `biometricStreamClient` / `biometricBatcher`. Confirm that `packages/breath_module/` and `packages/bci_module/` still do not import anything from `lib/Biometrics/` (the pipeline must remain passive background plumbing, per the spec).

## Commit Plan
- **Commit 1** (after tasks 1-7): "Wire biometric stream pipeline in App.initialize()"

<!-- orchestrator-sessions
planner: 9828fc77-8619-425b-ba2b-c56f0d26cdc7
elapsed: 554
implementer: 03fdaff1-0708-497e-ada6-b926260b75df
-->
