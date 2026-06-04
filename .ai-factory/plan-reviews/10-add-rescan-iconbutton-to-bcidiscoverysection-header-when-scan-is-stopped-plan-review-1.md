# Plan Review: Add rescan IconButton to BciDiscoverySection header

**Plan:** `10-add-rescan-iconbutton-to-bcidiscoverysection-header-when-scan-is-stopped.md`
**Files Reviewed:** 1 plan + 4 source files
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): ✅ Aligned. The change is confined to the presentation layer (`packages/bci_module/.../Views/`), touches no Service/Notifier/Repository, and reuses the existing `onRescan()` gesture on the ViewModel. The module boundary is respected — no domain model crosses into the view.
- **Rules** (`.ai-factory/RULES.md`): ✅ No violations. No module-specific state is added, App.dart is untouched, no new streams/subscriptions. The plan explicitly forbids touching the ViewModel/Service/domain.
- **Roadmap** (`.ai-factory/ROADMAP.md`): WARN — no roadmap linkage stated in the plan. This is a small UX recovery control (`feat`-class work); consider noting the milestone it belongs to, but non-blocking.

## Verification Against Codebase

All factual claims in the plan were verified against source:

- ✅ Line 90 is exactly `BciSectionHeader(title: l10n.bciPairingNearbyDevices),` — the replacement anchor is correct.
- ✅ `state` is read at line 84 via `ref.watch(bciPairingViewModelProvider)` and is reusable in `build()`.
- ✅ `state.isScanning` and `state.stage` exist on `BciPairingState`; `BciPairingStage.discovery` is a valid enum value.
- ✅ `onRescan()` exists on `BciPairingViewModel` (line 44) and calls `service.startScan()` — no ViewModel change needed.
- ✅ Import path `../Models/BciPairingStage.dart` is correct from `Views/`, and the import is genuinely required: `BciPairingState.dart` imports the enum but does not re-export it, so Dart will not surface `BciPairingStage` transitively. The plan's reasoning here is accurate.
- ✅ `BciDiscoverySection` is a `ConsumerStatefulWidget`; `ref` is available inside `build()` for the `IconButton.onPressed` callback.

## Critical Issues

None.

## Minor Notes (non-blocking)

- **`isConnecting` edge case:** The visibility condition `!state.isScanning && state.stage == BciPairingStage.discovery` does not exclude `isConnecting`. While the user taps a device and the connection spinner shows on a list tile (stage still `discovery`, `isScanning` false), the rescan button will be visible. Tapping it calls `service.startScan()` mid-connect. This is likely harmless but worth a conscious decision — consider `&& !state.isConnecting` if a rescan-during-connect should be suppressed.
- **No tooltip / semantics label** on the `IconButton`. A `tooltip:` (ideally localized via `l10n`) would improve accessibility. Optional given the "minimal" settings, but cheap to add.
- **Localization:** Consistent with the plan's `Docs: no` / minimal scope — no new strings are introduced, so the l10n ARB files need no change. Confirmed nothing references a missing key.

## Positive Notes

- Correctly scopes the change to a single view file and reuses the existing gesture — minimal blast radius.
- Accurately identifies the non-obvious transitive-import gotcha for `BciPairingStage`.
- Visibility predicate correctly hides the control while scanning (the `LinearProgressIndicator` already signals activity) and through impedance/calibrating/ready stages.

The plan is accurate, well-scoped, and architecturally sound. The minor notes are optional refinements, not blockers.

PLAN_REVIEW_PASS
