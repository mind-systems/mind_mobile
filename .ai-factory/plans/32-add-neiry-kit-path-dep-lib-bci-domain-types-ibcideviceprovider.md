# Plan: Add `neiry_kit` path dep + `lib/Bci/` domain types + `IBciDeviceProvider`

## Context
Lay the foundation for BCI integration: wire `neiry_kit` as a path-based plugin dependency and introduce a domain-pure abstraction layer (`lib/Bci/`) — typed domain models and the `IBciDeviceProvider` interface — that hides `neiry_kit` types from the rest of the app so future modules can depend on the abstraction rather than the plugin.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency wiring

- [x] **Task 1: Add `neiry_kit` path dependency to pubspec.yaml**
  Files: `pubspec.yaml`
  Add `neiry_kit:\n    path: ../neiry_kit` under the `# Internal packages` block in `dependencies:` (immediately after `mind_audio`). Keep the formatting consistent with the existing `mind_l10n` / `mind_ui` / `breath_module` / `mind_audio` entries (two-space indentation under `dependencies:`, four-space under the key). Do NOT add anything to `dev_dependencies`.

  **SDK constraint check (precondition for Task 2):** `neiry_kit/pubspec.yaml` declares `environment: sdk: ^3.11.0`, but the host `mind_mobile/pubspec.yaml` currently declares `environment: sdk: ^3.9.2`. Before running `flutter pub get`, verify the active Dart SDK is `>= 3.11.0` (`dart --version`). If `pub get` fails with an SDK incompatibility error, bump the host constraint in `mind_mobile/pubspec.yaml` to `environment: sdk: ^3.11.0` (a pubspec change, not a tooling install) and re-run. Make this bump as part of Task 1 only if it is required to satisfy resolution — otherwise leave the host constraint untouched.

- [x] **Task 2: Resolve dependencies via `flutter pub get`** (depends on Task 1)
  Files: `pubspec.lock`
  Run `/usr/local/bin/flutter pub get` from the project root (`/Users/max/projects/mind/mind_mobile`). Verify the command exits 0 and that `pubspec.lock` is updated with a `neiry_kit` entry. If resolution fails on the SDK lower bound, apply the fallback bump described in Task 1 and re-run. Note: `neiry_kit` ships native iOS/Android code; on iOS a subsequent `pod install` may be required before a real build, but for this foundation-only milestone (no usage yet) verifying `pubspec.lock` is sufficient — defer build-level validation to the milestone that first instantiates a concrete provider.

### Phase 2: Domain models

- [x] **Task 3: Create `BciDeviceInfo` domain model** (depends on Task 2)
  Files: `lib/Bci/Models/BciDeviceInfo.dart`
  Pure-Dart `@immutable` class with `final String serial` and `final String name`, declared `const` constructor with named required parameters. No imports from `neiry_kit` and no Flutter imports beyond `package:flutter/foundation.dart` for `@immutable` (consistent with existing domain models). This is the domain projection of `neiry_kit`'s `DeviceInfo` — the `type` field from the plugin model is deliberately omitted; conversion will happen later inside the concrete `IBciDeviceProvider` implementation.

- [x] **Task 4: Create `BciConnectionState` enum** (depends on Task 2)
  Files: `lib/Bci/Models/BciConnectionState.dart`
  Plain Dart enum with values: `disconnected`, `scanning`, `connecting`, `impedance`, `calibrating`, `ready`. Add a brief dartdoc on the enum stating that this is the app's BCI state-machine enum (distinct from `neiry_kit`'s lower-level `NeiryConnectionState`, which only models BLE link-layer state).

- [x] **Task 5: Create `BciSignalLevel` enum + `BciChannelQuality` model** (depends on Task 2)
  Files: `lib/Bci/Models/BciChannelQuality.dart`
  Co-locate the enum and its carrier in a single file (the enum is purely a derived signal-quality bucket with no use outside the channel-quality carrier; this is consistent with how `BreathSessionNotifierEvent.dart` co-locates a tightly coupled type family). Declare:
  - `enum BciSignalLevel { green, yellow, red }` (no payload).
  - `@immutable class BciChannelQuality` with `final String channelName`, `final double impedanceOhm`, `final BciSignalLevel level`. Const constructor, named required parameters. Use `package:flutter/foundation.dart` only for `@immutable`.
  No mapping helpers from `neiry_kit` — pure data carrier.

- [x] **Task 6: Create `BciCalibrationEvent` sealed hierarchy** (depends on Task 2)
  Files: `lib/Bci/Models/BciCalibrationEvent.dart`
  Use the modern Dart 3 sealed/final-class pattern (a stricter style than the existing `BreathSessionNotifierEvent.dart`, which predates `final`/`const` modifiers — we are not literally mirroring that file):
  - `sealed class BciCalibrationEvent { const BciCalibrationEvent(); }`
  - `final class BciCalibrationStageFinished extends BciCalibrationEvent { final int stage; const BciCalibrationStageFinished(this.stage); }`
  - `final class BciCalibrationCompleted extends BciCalibrationEvent { const BciCalibrationCompleted(); }` — explicitly no payload; per the milestone, `IndividualNfbData` from `neiry_kit` must NOT leak into the domain.
  - `final class BciCalibrationFailed extends BciCalibrationEvent { final String reason; const BciCalibrationFailed(this.reason); }` — `reason` is intentionally a free-form `String` (not a domain enum) for the foundation milestone; a future refactor may introduce a `BciCalibrationFailReason` enum if the UI needs to distinguish failure modes.
  No imports from `neiry_kit`.

### Phase 3: Provider interface

- [x] **Task 7: Create `IBciDeviceProvider` interface** (depends on Tasks 3-6)
  Files: `lib/Bci/IBciDeviceProvider.dart`
  Pure-Dart `abstract interface class IBciDeviceProvider` (or `abstract class` if the project's lint config doesn't permit `abstract interface class` — check `analysis_options.yaml` if needed; otherwise default to `abstract interface class`). Imports only the four domain models from `lib/Bci/Models/` and `dart:async` for `Stream`/`Future`. No `neiry_kit`, no Flutter, no Riverpod, no RxDart imports.

  Signatures (in this order). **Streams must be declared as getters, not fields** — `Stream<X> get name;` rather than `Stream<X> name;` — otherwise the abstract-field syntax would force implementers to provide a setter as well:
  - `Stream<List<BciDeviceInfo>> scan();` — one logical "scan session" per call; each call produces a fresh stream that emits one or more snapshots of currently-discovered devices and completes when the scan finishes (documented in dartdoc on the method).
  - `Future<void> connect(String serial);`
  - `Future<void> disconnect();`
  - `Stream<BciConnectionState> get connectionStateStream;`
  - `Stream<List<BciChannelQuality>> get signalQualityStream;`
  - `Stream<int> get batteryStream;`
  - `Stream<BciCalibrationEvent> get calibrationStream;`
  - `Future<void> startCalibration();`
  - `void dispose();` — dartdoc must specify: after `dispose()`, all observation streams are closed and any subsequent call on this instance is undefined; callers must construct a new provider instance to resume operation.

  Add a class-level dartdoc explaining: this is the domain-side abstraction for any BCI hardware provider; concrete implementations (e.g. a `neiry_kit`-backed adapter) live elsewhere and must translate plugin types into the `Bci` domain models declared in `lib/Bci/Models/`.

## Commit Plan
- **Commit 1** (after Tasks 1-2): "Add neiry_kit path dependency"
- **Commit 2** (after Tasks 3-6): "Add Bci domain models (device info, connection state, channel quality, calibration events)"
- **Commit 3** (after Task 7): "Add IBciDeviceProvider interface"
