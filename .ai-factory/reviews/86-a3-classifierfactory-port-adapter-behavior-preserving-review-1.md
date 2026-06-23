# Code Review: A3 · ClassifierFactory port + adapter (behavior-preserving)

**Scope reviewed:** `git diff HEAD` / `git status` — new ports `ClassifierSet.dart`, `ClassifierFactory.dart`; new adapters `NeiryClassifierSet.dart`, `NeiryClassifierFactory.dart`; modified `NeiryBciProvider.dart`, `NeiryDeviceAdapter.dart`; new test `neiry_bci_provider_classifier_port_test.dart`.

**Verification run:**
- `flutter analyze lib/Bci/ test/Bci/` → **No issues found.**
- `flutter test test/Bci/` → **All 41 tests passed** (new classifier-port suite + A1/A2 regression suites).

## Correctness assessment

The change is faithful to the plan and behavior-preserving. Specifics checked:

- **Build order preserved.** `NeiryClassifierSet` constructs `_nfb → _cardio → _emotions → _mems` via the initializer list (textual = declaration order), matching the former inline `connect()` order (`:172-175`). The `CardioClassifier` "device must be connected" precondition is still satisfied — `build()` runs after `await _device!.connect()`.
- **Dispose order preserved.** `NeiryClassifierSet.dispose()` disposes nfb → cardio → emotions → mems, each in its own `try/catch` + `logPrint`, exactly mirroring the former per-classifier error isolation. One classifier failing does not skip the rest. The provider's outer `try/catch` around `_classifierSet?.dispose()` (connect-failure, microtask Step 3, `_cancelDeviceSubscriptions`) is the throwable hook B2 needs, and `NeiryClassifierSet.dispose()` does not rethrow in production.
- **Teardown ordering untouched.** The microtask still runs stopStream → cancel subs → dispose classifiers → device.disconnect/dispose → `_resetLocatorSession` in `finally`. The `_teardownComplete` gate and `_resetLocatorSession` are unchanged.
- **Stream mapping relocated, semantics intact.** The five mapping bodies moved verbatim into `.map(...)`; MEMS fan-out moved from a `for` loop to `.expand((batch) => batch.map(...))`, which emits one `MotionData` per sample identically (empty batch → nothing). `source: SensorSource.neiry` / `hrv: null` tags preserved. Error events still reach each subscription's `onError` because `.map`/`.expand` forward source errors.
- **Cast relocated cleanly.** The `(device as NeiryDeviceAdapter).rawDevice` cast moved from inline `connect()` into `NeiryClassifierFactory.build()`. The A2 regression test confirms the default factory still throws `TypeError` when handed a non-adapter device, and the cleanup path still runs.
- **neiry confinement maintained.** `neiry_kit` is imported only by `NeiryClassifierSet`, `NeiryClassifierFactory`, `NeiryLocatorAdapter`, `NeiryDeviceAdapter`, and the provider (calibrator only — `NfbCalibrator`/`IndividualNfbData`/`CalibrationEvent`, out of scope as intended). No stray references to the removed `_nfbClassifier`/etc. fields or the old `TODO(A3)`.
- **Default wiring untouched.** `NeiryBciProvider()` defaults `_classifierFactory` to `NeiryClassifierFactory()`; `App.dart:193 NeiryBciProvider()` still compiles. Subscription field retypes (`_nfbSub` → `StreamSubscription<BciNfbData>?`, etc.) are consistent with the new domain-typed streams.
- **Doc-comment updated** on `NeiryDeviceAdapter.rawDevice` (now "Consumed by NeiryClassifierFactory", temporary A3 note dropped).

## Non-blocking observations (no action required)

1. **Mapping-throw routing nuance.** Previously a throw inside `_onNfbState`/etc. (the `listen` callback) would surface as an uncaught zone error; now a throw inside the `.map`/`.expand` transform routes to the subscription's `onError` and is logged. This is strictly safer and the transforms don't throw in practice — noted only for completeness, not a regression.
2. **Test-only leak.** In the `throwOnDispose` test, `FakeClassifierSet.dispose()` throws before closing its seven controllers, so they stay open. Harmless within the test process; the provider's subscriptions are already cancelled before the dispose call.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
