# Plan Review: Implement BciDataScreen + widgets (iteration 2)

**Plan:** `.ai-factory/plans/58-implement-bcidatascreen-widgets.md`
**Risk Level:** 🟢 Low — prior critical issues are addressed; only small wording / completeness nits remain.

## Context Gates

- **ARCHITECTURE.md:** PASS — work stays inside `packages/bci_module/`. The screen, header, and metric bar live under `BciData/Views/`, depend only on the in-package DTOs (`BciDataState`, `BciEmotionsDTO`, `BciNfbDTO`) and on the existing `IBciDataCoordinator` interface. No domain types are imported, no presentation code touches `lib/`. Module boundary preserved.
- **RULES.md:** PASS — no module-specific streams or wiring added to `App.dart`; the coordinator is reached only through the ViewModel-owned interface (`vm.onConnectPressed` / `vm.onHeaderTap`). No public getter on the coordinator instance is added. Service/coordinator concretes are explicitly deferred to roadmap items 129 / 131.
- **ROADMAP.md:** PASS — matches roadmap line 127 ("Implement `BciDataScreen` + widgets"). Follow-up wiring (route, HomeCoordinator, Module assembly) is correctly out of scope; matches lines 129 + 131.

## Iteration 1 → 2 Diff

All seven action items from the previous review are addressed:

1. ✅ Task 4↔5 dependency reversed: VM methods are now added in Task 2 (Phase 2) **before** the widgets that call them.
2. ✅ Heart-rate concatenation bug fixed: separate `bciHeartRate` label, numeric value, and new `bciBpm` unit; no `'${value} ${l10n.bciHeartRate}'`.
3. ✅ `final l10n = AppLocalizations.of(context)!;` and the `AppLocalizations` import path are both explicit in Task 5.
4. ✅ Shared-folder reorg explicitly deferred in the Context section.
5. ✅ Task 5 no longer claims the coordinator field is "private" — Task 2 instead documents the rule as "do not expose the coordinator through any public getter; only intent-named callbacks".
6. ✅ Single wiring pattern for `BciDataHeader`: it owns the provider read and calls `vm.onHeaderTap()` directly; no constructor `VoidCallback`.
7. ✅ Battery opacity now gates on `state.isConnected && state.batteryPercent != null`.

## Critical Issues

None.

## Minor Issues / Suggestions

### 1. `textTheme` binding missing in Task 5 build snippet
Task 5 references `textTheme.bodyMedium`, `textTheme.titleLarge`, and `textTheme.bodySmall` in the heart-rate row, but the build setup only declares `state`, `vm`, and `l10n`. Add `final textTheme = Theme.of(context).textTheme;` (or use `Theme.of(context).textTheme.bodyMedium` inline) to avoid an implementer omission and a compile error.

### 2. `BciSignalQuality` import for `BciDataHeader` not spelled out
Task 4 defines a top-level `Color _impedanceColor(BciSignalQuality q)` helper but does not say where `BciSignalQuality` comes from. It lives in `packages/bci_module/lib/src/BciPairing/Models/BciChannelQualityDTO.dart`. Add an explicit import note (`import '../../BciPairing/Models/BciChannelQualityDTO.dart';`) so the implementer doesn't have to hunt — and so the cross-feature reach is acknowledged on paper (it is the same coupling pre-existing in `BciDataState`).

### 3. `BciMetricBar` layout not fully described
Task 3 says the widget is "a fixed-width vertical container (~36dp wide, ~120dp max bar height)" with "a bottom-aligned bar" and a label below. The implementer will have to decide between:

- `SizedBox(width: 36)` + `Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(height: 120, child: Align(alignment: Alignment.bottomCenter, child: AnimatedContainer(...))), label])`
- or stacking via `Stack` + `Positioned`.

Either works, but explicitly nominating one (the `Align(Alignment.bottomCenter)` form is conventional in this repo) prevents drift. Not a blocker — both implementations satisfy the spec.

### 4. `AnimatedContainer` width
Task 3 specifies `~36dp wide` but doesn't say whether the inner `AnimatedContainer` should be full-width within the column or narrower (e.g. a centered bar with padding). The visual intent in `.ai-factory/notes/24-bci-data-screen.md` reads "vertical bars". Suggest stating that the bar's `width` equals the column's width (i.e. fills it). Minor.

### 5. Empty-state column horizontal padding
Task 5's `!state.isConnected` branch uses `Center(child: Column(...))` with no `Padding`. The `FilledButton` will render at intrinsic width with the message above it — fine for short strings, but the Russian "Устройство не подключено" (29 chars) on a narrow device may benefit from horizontal padding (e.g. `Padding(symmetric(horizontal: 32))`). Not a correctness issue; ergonomic suggestion.

### 6. `flutter analyze` reach
Task 1 says "Run `flutter analyze` from the package to confirm regenerated files are clean." Worth saying "from `packages/mind_l10n/`" explicitly — the project has multiple package dirs and a monorepo root, and the user rule mandates the `/usr/local/bin/flutter` absolute path. The plan does name the absolute path earlier, but reasserting it for the `analyze` line removes ambiguity.

### 7. Documentation: rule about not mixing label with unit
Task 1 already clarifies `bciHeartRate` is a label and `bciBpm` is a unit. Consider mirroring that intent in Task 5 step 1's prose (it already says *"never concatenated as `'$value $bciHeartRate'`"*, which is great). No change needed — calling it out as a positive.

## Cross-checks against the codebase

- `IBciDataCoordinator.openPairing()` exists ✓
- `BciDataViewModel.coordinator` is a public field — `vm.onConnectPressed = () => coordinator.openPairing()` compiles ✓
- `BciDataState.channels: List<BciChannelQualityDTO>` exists and starts empty ✓
- `BciDataState.batteryPercent: int?` exists ✓
- `BciDataState.isConnected: bool` exists ✓
- `BciEmotionsDTO` exposes `attention / cognitiveLoad / relaxation / cognitiveControl / selfControl` as `double?` — matches the five emotion bars ✓
- `BciNfbDTO` exposes `delta / theta / alpha / smr / beta` as `double?` — matches the five EEG bars ✓
- `BciSignalQuality` enum (`good`, `fair`, `poor`) is in `BciPairing/Models/BciChannelQualityDTO.dart` — matches the three colors in `_impedanceColor` ✓
- `BciSectionHeader` is a `StatelessWidget` with `String title` — reuse pattern is correct ✓
- `AppLocalizations` is re-exported from `package:mind_l10n/mind_l10n.dart` (used identically in `BciPairingScreen`) ✓
- Existing l10n keys end with `bciOpenSettings` — Task 1's "append after `bciOpenSettings`" matches the actual ARB layout ✓
- Barrel `bci_module.dart` already exports `BciPairingScreen` under a `// Screens` section — Task 6's "immediately after the `BciPairingScreen` export" matches reality ✓
- `BciDataHeader`'s opacity rule (battery greys when `!isConnected || batteryPercent == null`) is consistent with `_BciPairingHeader` (which only checks `batteryPercent != null` but never displays the header in a disconnected state) — design choice is sound

## Positive Notes

- Phase ordering (l10n → ViewModel → reusable widgets → screen → barrel) cleanly respects compile-time dependencies.
- Task 2 picks the correct architectural seam: intent-named VM callbacks instead of exposing the coordinator.
- Task 3's `BciMetricBar` API (`double? value`, `Color color`, `String label`) is minimal and reusable; defensive clamp to `0..1` and `null → 0 height + 0.3 opacity` captures the notes' intent.
- Task 4's `BciDataHeader` correctly owns its provider read, avoiding the redundant callback-vs-provider duality that was called out in iteration 1.
- The disconnected-header uniformity rule (battery opacity gated on `isConnected && batteryPercent != null`, impedance dots forced to grey/0.3 when channels empty) is well stated.
- Heart-rate row is now correctly composed (`label` + `value` + `BPM` unit) — closes the iteration-1 critical bug.
- Plan explicitly notes that band names (Delta/Theta/Alpha/SMR/Beta) are **not** localized — matches the notes file and conventional usage.
- Task 6's scope (export only the screen, keep `BciDataHeader` and `BciMetricBar` package-internal) preserves encapsulation.
- The shared-folder deferral is now documented in the Context section, removing the "unannounced cross-feature coupling" risk flagged previously.
- Task 1 includes the correct verification path (`flutter analyze`) and respects the global `/usr/local/bin/flutter` rule.

## Recommended Plan Edits Before Implementation

Optional — all non-blocking:

1. Add `final textTheme = Theme.of(context).textTheme;` to Task 5's build setup.
2. Name the import for `BciSignalQuality` in Task 4 (`../../BciPairing/Models/BciChannelQualityDTO.dart`).
3. Pin down the bar's intrinsic layout in Task 3 (suggest `SizedBox(height: 120) + Align(bottomCenter, child: AnimatedContainer)`).

PLAN_REVIEW_PASS
