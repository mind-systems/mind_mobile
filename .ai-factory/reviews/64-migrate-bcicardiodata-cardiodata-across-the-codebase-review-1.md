# Code Review: Migrate `BciCardioData` → `CardioData` across the codebase

**Plan:** `64-migrate-bcicardiodata-cardiodata-across-the-codebase.md`
**Files Reviewed (full contents):**
- `lib/Bci/Models/BciNotifierEvent.dart`
- `lib/Bci/IBciDeviceProvider.dart`
- `lib/Bci/BciDeviceManager.dart`
- `lib/Bci/NeiryBciProvider.dart`
- `lib/BciModule/BciDataService.dart` (downstream consumer, unchanged)
- `lib/Bci/BciNotifier.dart` (downstream consumer, unchanged)
- `lib/Biometrics/Models/CardioData.dart` (new target type)
- `lib/Biometrics/Models/SensorSource.dart`
- `neiry_kit/lib/src/models/cardio_data.dart` (SDK source type, for field/timestamp confirmation)
- Git `status` + `diff HEAD` for the staged change set
**Risk Level:** 🟢 Low

## Verification Checklist

| Check | Result |
|---|---|
| Project-wide grep for `BciCardioData` in `lib/` after the change | ✓ zero hits |
| Project-wide grep for `BciCardioData` in `test/` and `packages/*/test/` | ✓ zero hits |
| `lib/Bci/Models/BciCardioData.dart` deleted (staged) | ✓ |
| `IBciDeviceProvider.cardioStream` returns `Stream<CardioData>` | ✓ line 54 |
| `BciDeviceManager.cardioStream` returns `Stream<CardioData>` | ✓ line 81 |
| `BciCardioUpdated.data` field typed `CardioData` | ✓ line 58 in `BciNotifierEvent.dart` |
| `NeiryBciProvider` imports `neiry_kit` aliased as `neiry` | ✓ line 6 |
| All SDK type references in `NeiryBciProvider` prefixed with `neiry.` | ✓ lines 27, 28, 30–32, 45–46, 48–49, 51–52, 120, 139–141, 212–218, 226, 260, 273, 286, 302, 305, 309 |
| `_cardioController` is `StreamController<CardioData>` (our type) | ✓ line 42 |
| `_cardioSub` is `StreamSubscription<neiry.CardioData>?` (SDK type) | ✓ line 51 |
| `_onCardioState` constructs `CardioData(...)` with `timestamp: c.timestamp`, `source: SensorSource.neiry`, `hrv: null` | ✓ lines 273–282 |
| SDK `CardioData.timestamp` is `DateTime` → assigns directly to our `DateTime` field | ✓ (verified `neiry_kit/lib/src/models/cardio_data.dart:21`) |
| `BciNotifier` subscriptions still `StreamSubscription<dynamic>?` (no edit needed) | ✓ unchanged |
| `BciDataService` reducer field accesses (`data.heartRate`, `data.metricsAvailable`, `data.hasArtifacts`) resolve against `CardioData` | ✓ — all three fields exist with the same types (`double`, `bool`, `bool`) |

## Critical Issues

None.

## Minor Issues / Nits

1. **`BciDataService.dart` was not given an explicit `CardioData` import.** The plan's Task 5 made the import conditional on analyzer feedback; the implementer did not add it. This compiles correctly because Dart resolves field access on a destructured `data: CardioData` through the transitive import in `BciNotifierEvent.dart` — so it is functionally fine. However, the file already imports its other event-payload types explicitly (`BciConnectionState`, `BciChannelQuality`), so the missing import is the only stylistic deviation from the file's own convention. Non-blocking; recommend adding `import 'package:mind/Biometrics/Models/CardioData.dart';` for consistency if the implementer touches this file again.

2. **Import grouping/ordering regressed in four files.** The new `package:mind/Biometrics/Models/CardioData.dart` import was inserted between sibling `package:mind/Bci/Models/...` lines rather than added to its own group or kept alphabetically grouped by directory:
   - `BciDeviceManager.dart:8` — placed between `BciChannelQuality.dart` and `BciConnectionState.dart` (breaks alphabetical run inside the Bci/Models cluster).
   - `BciNotifierEvent.dart:3` — placed between `BciChannelQuality.dart` and `BciConnectionState.dart`.
   - `IBciDeviceProvider.dart:3` — added between `dart:async` and the relative `Models/...` block. Functionally correct (different group); cosmetically fine.
   - `NeiryBciProvider.dart:9–10` — placed between the external packages block and the relative `Models/...` block, which is reasonable.

   No correctness impact; analyzer-only nit. Non-blocking.

3. **`_locator` field lost its explicit type annotation.** Original: `final DeviceLocator _locator = DeviceLocator();`. New: `final _locator = neiry.DeviceLocator();`. The plan's Task 4 step 3 listed `DeviceLocator()` → `neiry.DeviceLocator()` but did not call out the type annotation separately; the implementer chose to drop the annotation and rely on inference rather than write `final neiry.DeviceLocator _locator = neiry.DeviceLocator();`. Both are valid; type is inferred to `neiry.DeviceLocator` so behavior is identical. Non-blocking.

4. **No comment marker for deferred HRV wiring.** `_onCardioState` passes `hrv: null` and silently drops the SDK's `stressIndex` and `kaplanIndex` — both are non-trivial signals the firmware computes. The plan correctly defers HRV population per note 27, but the migrated mapper has no inline marker pointing future readers at that note. A one-line `// TODO(notes/27): map c.stressIndex/c.kaplanIndex → CardioHrvIndices once the HRV milestone lands.` would prevent the deferral from becoming an invisible regression. Non-blocking.

## Runtime Risk Assessment

- **Type/contract changes:** The `IBciDeviceProvider.cardioStream` contract changed (return type), and the sole implementer (`NeiryBciProvider`) was updated in the same commit set. The sole consumer above it (`BciDeviceManager`) was likewise updated, as was the notifier event payload and the reducer's destructure (no logic change required). No external implementer of `IBciDeviceProvider` exists in the workspace (verified by grep across `lib/`, `test/`, and `packages/`).
- **Drift schema / migrations:** Not touched; not relevant — `CardioData` is a transient stream value, not persisted.
- **Proto contracts:** Not touched.
- **Race conditions / lifecycle:** No subscription wiring changed in `NeiryBciProvider` — only generic type parameters and mapper signatures. `_cardioController` still constructed eagerly, closed in `_doDispose`, with the listener attached in `_subscribeDeviceStreams` and torn down in `_cancelDeviceSubscriptions`. Behavior is unchanged.
- **`BciNotifier` `StreamSubscription<dynamic>?` cardio subscription:** continues to accept whatever the underlying stream emits — its `_subject.add(BciCardioUpdated(data))` call now wraps a `CardioData` (new type) but the `BciCardioUpdated` constructor parameter is unannotated (`this.data`), so the field's static type silently follows the new declaration. No runtime hazard.
- **Downstream consumers that read the cardio payload:** only `BciDataService._reduce` (`data.heartRate.round()`, `data.metricsAvailable`, `data.hasArtifacts`). All three field names and types match between `BciCardioData` and `CardioData`. Verified by reading both class definitions in full.
- **Tests:** none reference the removed type, the renamed stream, or the event variant — nothing breaks.
- **Symbol-clash safety:** the `as neiry` alias correctly disambiguates the SDK's `CardioData` from ours throughout `NeiryBciProvider`. No bare `CardioData` reference in that file resolves to the SDK type (every SDK use site is prefixed). Confirmed exhaustively by reading the full file post-change.

## Positive Notes

- The alias-import migration in `NeiryBciProvider` was carried out exhaustively; every SDK type reference (field, local, subscription generic, classifier construction, mapper signature, switch-case pattern, scan call, calibrator call) is correctly prefixed with `neiry.`.
- The cardio symbol collision is the actual reason an alias is needed — and the implementation correctly uses our `CardioData` for the controller/getter/emit site while keeping the subscription generic and mapper parameter typed as `neiry.CardioData`. The two-symbol disambiguation is the most error-prone part of the migration and was done cleanly.
- `BciNotifier`'s `StreamSubscription<dynamic>?` design from Phase 19 paid off here — it requires zero edits to handle the type change, which the plan correctly recognized.
- Field-name parity between `BciCardioData` and `CardioData` means the reducer body needs no changes — the plan's cross-file check matched reality.
- The plan correctly scoped out the capability split (separating `cardioStream` from `IBciDeviceProvider`); that work stays clean for the next milestone.

REVIEW_PASS
