## Plan Review

**Plan:** `32-add-neiry-kit-path-dep-lib-bci-domain-types-ibcideviceprovider.md`
**Risk Level:** 🟡 Medium — one concrete syntax bug that will fail `flutter analyze`, plus a likely SDK-constraint mismatch that can block `pub get`.

### Context Gates
- **ARCHITECTURE.md** — PASS. `lib/Bci/` mirrors the existing pattern (`lib/BreathModule/`, `lib/User/`, `lib/McpModule/`). Pure-Dart domain types with no Flutter/Riverpod imports respect the "Notifier and Repository must NOT import `flutter/` or `riverpod`" rule (the new files sit at the domain layer).
- **RULES.md** — PASS. No service/notifier/coordinator are introduced yet; the rules around stateless services and constructor-injection are not in scope.
- **ROADMAP.md** — PASS. The plan is the first unchecked item under "Phase 17 — BCI Device Pairing" and matches the roadmap line verbatim (model fields, enum values, sealed event subtypes, and method list).

### Critical Issues

**1. `IBciDeviceProvider` stream members declared as fields, not getters (Task 7)**

The plan lists:
```
Stream<BciConnectionState> connectionStateStream;
Stream<List<BciChannelQuality>> signalQualityStream;
Stream<int> batteryStream;
Stream<BciCalibrationEvent> calibrationStream;
```

In an `abstract interface class`, this syntax declares **abstract fields**, which require both a getter *and* a setter from implementers. That is almost certainly not the intent — these are read-only observation streams. Implementers (`NeiryBciProvider` in the next milestone) will be forced to implement a setter for each, or `analyzer` will flag the implementation as incomplete.

Fix: declare them as getters:
```dart
Stream<BciConnectionState> get connectionStateStream;
Stream<List<BciChannelQuality>> get signalQualityStream;
Stream<int> get batteryStream;
Stream<BciCalibrationEvent> get calibrationStream;
```

This is also consistent with the existing notifier pattern (`Stream<BreathSessionNotifierEvent> get stream` in `BreathSessionNotifier`).

**2. SDK constraint mismatch between host and `neiry_kit` (Task 2)**

`mind_mobile/pubspec.yaml` declares `environment: sdk: ^3.9.2`, but `neiry_kit/pubspec.yaml` declares `environment: sdk: ^3.11.0`. `flutter pub get` will resolve only when the active Dart SDK satisfies **both** constraints (≥ 3.11.0 < 4.0.0). If the dev environment is on Dart 3.9.x or 3.10.x, Task 2 will fail with an SDK incompatibility error.

The plan should either:
- Add a note acknowledging the mismatch and that the host's lower bound may need to be bumped to `^3.11.0` (this is a pubspec.yaml change, not a tooling installation), or
- Verify the active Dart SDK is ≥ 3.11.0 before Task 2.

This is non-blocking on a current machine but is a likely friction point that should be called out.

### Non-Critical Issues / Suggestions

**3. "Mirrors the project's sealed-event pattern" is inaccurate (Task 6)**

The plan claims it mirrors `BreathSessionNotifierEvent.dart`, but that file uses plain `class X extends BreathSessionNotifierEvent` with no `final` modifier and no `const` constructors. The plan prescribes `final class` + `const` constructors, which is the *better* Dart 3 sealed-class style — but it is not what the existing file does. Either:
- Update the wording to: "Use the modern Dart 3 sealed/final class pattern (an improvement over `BreathSessionNotifierEvent` which predates these modifiers)", or
- Drop the `final` and `const` to literally mirror the existing file.

The plan's chosen style is preferable; only the framing is misleading.

**4. iOS native side-effects after `pub get` not mentioned (Task 2)**

`neiry_kit` ships native iOS and Android code (`neiry_kit/ios/`, `neiry_kit/android/`). On iOS, the first `flutter pub get` typically triggers `pod install` automatically, but if it doesn't, a subsequent build will fail until pods are installed. Task 2's success criterion is just "exits 0 and `pubspec.lock` updated"; consider adding "and `flutter build apk --flavor dev` (or at least `flutter analyze`) succeeds" to catch native-link breakage early — though this is foundation-only code with no usage yet, so deferring is reasonable.

**5. Phase-2 dependency on Task 2 is over-conservative**

Tasks 3–6 declare `(depends on Task 2)`. The domain models in those tasks import nothing from `neiry_kit` (only `package:flutter/foundation.dart` for `@immutable`), so they could compile and be reviewed in parallel with Task 2. This is a minor sequencing observation, not an error — keeping the dependency is safe and predictable.

**6. `BciCalibrationFailed.reason: String` discards `NfbCalibrationFailReason` (Task 6)**

`neiry_kit` exports `NfbCalibrationFailReason` as a structured enum. The plan domesticates this into a free-form `String`, which is consistent with the milestone's "no `neiry_kit` types in domain" rule but loses type safety. Acceptable for the foundation milestone — flagged so a future refactor knows to introduce a domain `BciCalibrationFailReason` enum if the UI needs to distinguish failure modes.

**7. Task 5 packs two declarations into one file**

`BciSignalLevel` enum + `BciChannelQuality` model in `BciChannelQuality.dart` is fine (Dart convention for tightly coupled enum + carrier), but the project's convention so far is one type per file (`BreathSessionNotifierEvent.dart` is the exception — also a sealed family). Either accept this co-location for the same reason, or split `BciSignalLevel.dart` into its own file for consistency with `BciConnectionState.dart`. Minor stylistic call; co-location is defensible because the enum is purely a derived signal-quality bucket and has no use outside the channel-quality carrier.

**8. `dispose()` semantics on the interface (Task 7)**

`void dispose();` is the only "lifecycle" method on `IBciDeviceProvider`. Worth adding a one-line dartdoc clarifying that after `dispose()`, all streams must be closed and further calls are undefined — otherwise the future `BciDeviceManager` won't know if it can safely rebuild the provider.

### Positive Notes

- Plan correctly identifies that `lib/Device/` is unrelated (device-ping telemetry) and avoids name collision by choosing `lib/Bci/`.
- The deliberate omission of `DeviceInfo.type` (Task 3) and `IndividualNfbData` (Task 6) is well justified and aligned with the milestone's domain-isolation goal.
- Commit plan is clean (3 logical commits aligned with the 3 phases).
- Imports are explicitly scoped — domain models pull only `package:flutter/foundation.dart`, interface pulls only `dart:async` + the four models. This will make it trivial to extract `lib/Bci/` into its own package later if needed.
- The dartdoc note on `BciConnectionState` distinguishing it from `NeiryConnectionState` is exactly the kind of preventative comment that pays off when a future contributor wonders why two enums exist.
- Task 7's signature ordering puts query streams (`scan`, `connect`, `disconnect`) before observation streams before commands (`startCalibration`), which reads logically.

### Suggested Edits Before Implementation

1. Change all four `Stream<...> name;` declarations in Task 7 to `Stream<...> get name;` (blocker).
2. Add a precheck/note to Task 2 about the `neiry_kit` SDK lower bound being `^3.11.0` (likely-blocker).
3. Reword Task 6's "mirror the project's sealed-event pattern" sentence to remove the `BreathSessionNotifierEvent.dart` claim (or drop `final`/`const` to match).
4. Add one-line dartdoc on `IBciDeviceProvider.dispose()` describing post-dispose stream/method semantics.
