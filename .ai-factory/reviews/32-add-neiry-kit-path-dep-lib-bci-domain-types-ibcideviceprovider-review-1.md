## Code Review

**Plan:** `32-add-neiry-kit-path-dep-lib-bci-domain-types-ibcideviceprovider.md`
**Scope:** `pubspec.yaml`, `pubspec.lock`, `lib/Bci/IBciDeviceProvider.dart`, `lib/Bci/Models/{BciDeviceInfo,BciConnectionState,BciChannelQuality,BciCalibrationEvent}.dart`, `.ai-factory/DESCRIPTION.md`.

### Verification

- `flutter analyze lib/Bci` → `No issues found! (ran in 1.3s)`.
- `pubspec.lock` updated with `neiry_kit` (path: `../neiry_kit`, version 0.0.1).
- All five new files are pure Dart; the only Flutter import is `package:flutter/foundation.dart` for `@immutable` on `BciDeviceInfo` / `BciChannelQuality`. No `neiry_kit`, `riverpod`, or `rxdart` imports anywhere — domain isolation rule honored.

### Plan Adherence

| Task | Status |
|---|---|
| 1 — `neiry_kit` path dep added under `# Internal packages`, after `mind_audio`; SDK lower bound bumped to `^3.11.0` (the documented fallback) | ✅ |
| 2 — `flutter pub get` resolved; `pubspec.lock` carries `neiry_kit` | ✅ |
| 3 — `BciDeviceInfo` with `serial`, `name`; `@immutable`, const ctor; `type` deliberately omitted | ✅ |
| 4 — `BciConnectionState` enum with all six values; dartdoc distinguishes from `NeiryConnectionState` | ✅ |
| 5 — `BciSignalLevel` + `BciChannelQuality` co-located; const ctor, named required params | ✅ |
| 6 — Sealed `BciCalibrationEvent` with `StageFinished(int stage)` / `Completed()` (no payload) / `Failed(String reason)`; `IndividualNfbData` does not leak | ✅ |
| 7 — `abstract interface class IBciDeviceProvider`; streams as **getters** (the review-1 blocker); class-level + `dispose()` dartdoc present | ✅ |

### Findings

**No bugs, security issues, or correctness problems identified.**

A few low-priority observations, none of which require code changes:

1. **`dart:async` import is technically redundant** in `IBciDeviceProvider.dart` — `Stream` and `Future` are re-exported through `dart:core`. Harmless and arguably documentary; analyzer does not flag it. Not worth changing.
2. **No `==` / `hashCode` on `BciDeviceInfo` or `BciChannelQuality`.** Already flagged and accepted in plan-review-2; downstream de-duplication (e.g. scan results by serial) can be handled at the manager layer.
3. **Host SDK lower bound bumped from `^3.9.2` → `^3.11.0`.** Required by `neiry_kit`'s constraint; correctly mirrored in `.ai-factory/DESCRIPTION.md` ("Dart 3.3+" → "Dart 3.11+"). Every other Flutter packages folder (`packages/breath_module`, `packages/mind_audio`, `packages/mind_ui`, `packages/mind_l10n`) should be re-checked in a follow-up only if their declared SDK floor is now higher than the host's — out of scope for this milestone.
4. **`disconnect()` semantics on a not-connected provider** are unspecified. Acceptable at the interface level; concrete implementation milestone can decide whether to no-op or throw.
5. **iOS `pod install`** is intentionally deferred per the plan; no concrete provider is wired in yet, so a build is not exercised.

REVIEW_PASS
