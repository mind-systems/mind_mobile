# Code Review: Add rescan IconButton to BciDiscoverySection header

**Files reviewed:** `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart` (only source change)
**Risk:** 🟢 Low

## Scope of changes

Single source file modified. The diff:
- Adds `import '../Models/BciPairingStage.dart';`
- Wraps the section header in a `Row` with `Expanded(child: BciSectionHeader(...))` and a conditional `IconButton(Icons.refresh)` gated on `!state.isScanning && state.stage == BciPairingStage.discovery`, calling `ref.read(bciPairingViewModelProvider.notifier).onRescan()`.

The remaining staged files are plan/plan-review/JSON artifacts — not code.

## Verification against codebase

- ✅ `onRescan()` exists on `BciPairingViewModel` (line 44) and delegates to `service.startScan()`. No ViewModel/Service/domain change needed, as the plan states.
- ✅ `BciPairingStage.discovery` is a valid enum member (`BciPairingStage.dart`).
- ✅ `state.isScanning` and `state.stage` are real fields on `BciPairingState`.
- ✅ The new import is genuinely required: `BciPairingState.dart` imports `BciPairingStage.dart` but does not re-export it, so the enum is not transitively visible in the view. Without the import the code would not compile.
- ✅ `ref` is available inside `build()` (`ConsumerStatefulWidget`); `state` is read once at line 85 and reused.
- ✅ Layout is sound: `Row` inside a `crossAxisAlignment: stretch` `Column` defaults to `mainAxisSize.max`, `Expanded` consumes remaining width, the trailing `IconButton` sizes naturally. No unbounded-width or overflow risk.

## Correctness / runtime

No bugs found. No type mismatches, null-safety issues, missing migrations, or race conditions. The change is presentation-only and matches the plan and spec exactly.

## Minor observation (non-blocking, matches spec)

- **Button visible during an in-flight connect.** The guard does not exclude `isConnecting`. When a user taps a device, `isConnecting` becomes `true` while `stage` remains `discovery` and `isScanning` is `false`, so the rescan button stays visible and tapping it would call `startScan()` mid-connect. This is exactly the guard the spec/plan prescribed and is at worst a minor UX nuance, not a correctness defect. If suppressing rescan during connect is desired, add `&& !state.isConnecting` — but this is optional and outside the agreed scope.

The implementation is correct, minimal, and faithful to the plan.

REVIEW_PASS
