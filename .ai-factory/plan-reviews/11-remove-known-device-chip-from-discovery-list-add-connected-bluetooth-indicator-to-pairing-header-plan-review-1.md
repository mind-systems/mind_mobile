# Plan Review: Remove known-device chip; add connected Bluetooth indicator to pairing header

**Plan:** `11-remove-known-device-chip-from-discovery-list-add-connected-bluetooth-indicator-to-pairing-header.md`
**Risk Level:** 🟢 Low

## Verification Summary

Every concrete claim in the plan was checked against the codebase and confirmed:

| Claim | Status |
|---|---|
| Chip callsite at `BciDiscoverySection.dart` lines 132–137 | ✅ Exact match |
| `l10n.bciPairingKnownDevice` has only one callsite (this file) | ✅ Confirmed via grep — only `BciDiscoverySection.dart:134` references it |
| `_BciPairingHeader.build()` `Row` starts at line 57, battery `Opacity` block follows | ✅ Confirmed |
| `state` already watched in `_BciPairingHeader` (no new provider read) | ✅ `ref.watch(bciPairingViewModelProvider)` at line 51 |
| `state.stage` / `BciPairingStage` available in header | ✅ Already used at line 75 |
| `BciPairingStage` enum = `{ discovery, impedance, calibrating, ready }` | ✅ `stage != discovery` correctly means "connected" |
| `app_en.arb` key at line 125 = `"Paired"` | ✅ Confirmed |
| `app_ru.arb` key at line 119 = `"Сопряжено"` | ✅ Confirmed |
| No `@bciPairingKnownDevice` metadata block exists in either ARB | ✅ Confirmed — plain keys only, nothing extra to delete |
| `withValues(alpha:)` API is supported | ✅ Used in 5+ files across packages |
| l10n codegen via `flutter gen-l10n` | ✅ `l10n.yaml` present; arb-dir `lib/l10n`, output `app_localizations.dart`, `synthetic-package: false` |

The plan is also a faithful, complete transcription of the source note `76-bci-pairing-known-badge-remove-bt-indicator.md`.

## Correctness Checks

- **No dangling references:** After Task 1, `l10n` is still used in `BciDiscoverySection` (`bciPairingNearbyDevices`, the Bluetooth-permission strings), so the `l10n` local and the `mind_l10n` import remain valid — no unused-variable/import lint. Same for `_BciPairingHeader`, where `l10n.bciPairingDisconnect` keeps `l10n` alive.
- **Model untouched is correct:** Leaving `device.isKnown` and `BciScannedDeviceDTO.isKnown` in place is the right call — `isKnown` may still drive non-UI logic and the change is scoped to presentation.
- **`stage != discovery` is consistent** with the existing disconnect-button gate (`onPressed: state.stage == BciPairingStage.discovery ? null : ...`), so "connected" is defined the same way the header already defines it.
- **Task ordering is sound:** Task 3 depends on Task 1 (remove callsite before deleting key), Task 4 depends on Task 3 (regenerate after ARB edit). Correct dependency chain.

## Context Gates

- **Architecture:** Change stays entirely inside the `packages/bci_module` presentation package and `packages/mind_l10n` — no domain/module boundary crossing, no DTO contract change, no service interface touched. Aligned with the module-system rules in `CLAUDE.md`. ✅
- **Rules:** No proto, no migration, no auth surface involved. ✅
- **Roadmap:** Item is tracked in `.ai-factory/ROADMAP.md` (line 39). ✅

## Non-blocking Notes (WARN)

1. **Hardcoded colors vs. theme tokens.** The plan hardcodes `Colors.blue` and `Colors.white.withValues(alpha: 0.3)`. The project has theme tokens (`docs/core/theming.md`, `mind_ui/AppTheme`). However, this same file already uses a hardcoded `Colors.red` for the disconnect button, so the plan is *consistent with existing local style*. The `Colors.white` dim color also assumes a dark header background — note that the adjacent battery icon uses the default (theme-driven) icon color rather than an explicit white, so the new icon will not perfectly track the battery icon under a light theme. Acceptable for this screen, but worth a glance during implementation.

2. **Transient connecting state.** While a device is connecting, `stage` is still `discovery` (only `isConnecting` is true), so the Bluetooth icon stays dim until the stage advances to `impedance`. This matches the note's intended behavior ("dim during scanning, blue after connecting"), so it's by design — flagged only so the implementer doesn't mistake it for a bug.

3. **Verification step is manual-only** (Settings say Testing: no). Given the trivial UI nature, that's reasonable.

## Conclusion

The plan is accurate, internally consistent, correctly ordered, and faithful to the source note. All file paths, line numbers, API usage, and l10n tooling were verified against the actual codebase. No missing steps, no wrong assumptions, no architectural issues. The notes above are minor stylistic observations, not blockers.

PLAN_REVIEW_PASS
