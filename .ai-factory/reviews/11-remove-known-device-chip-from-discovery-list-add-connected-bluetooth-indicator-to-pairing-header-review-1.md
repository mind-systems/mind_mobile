# Code Review: Remove known-device chip; add connected Bluetooth indicator to pairing header

**Scope:** `git diff HEAD` — 2 Dart UI files, 2 ARB files, 3 generated localization files.

## Verification

- **`BciDiscoverySection.dart`** — `trailing` changed to `null`; the `Chip(Text(l10n.bciPairingKnownDevice))` block removed. The `l10n` local is still used (`bciPairingNearbyDevices`, the Bluetooth-permission strings), so no unused-variable/import lint. `device.isKnown` left intact in the model as intended. ✅
- **`BciPairingScreen.dart`** — `isConnected = state.stage != BciPairingStage.discovery` added; `Icon(Icons.bluetooth, size: 16, color: …)` + `SizedBox(width: 4)` prepended as the first children of the header `Row`, before the battery `Opacity`. Imports cover all symbols used: `flutter/material.dart` (line 1) provides `Icon`/`Icons`/`Colors`/`withValues`; `BciPairingStage` imported (line 6); `state` already watched (line 51). The `Icon` is correctly non-`const` since its color is runtime-dependent. ✅
- **ARB files** — `bciPairingKnownDevice` removed from both `app_en.arb` and `app_ru.arb`; no `@bciPairingKnownDevice` metadata existed, so nothing dangling. ✅
- **Generated localizations** — `app_localizations.dart` (abstract getter), `app_localizations_en.dart`, and `app_localizations_ru.dart` all have the getter cleanly removed, consistent with the ARB edits. This matches what `flutter gen-l10n` produces; the files were not hand-edited in any way that diverges from the ARB source. ✅
- **No dangling code references** — `bciPairingKnownDevice` now appears only in `ROADMAP.md` and the source note (as prose), not in any compiled code. ✅

## Correctness / runtime

No bugs found. The change is purely presentational: no provider contract change, no DTO/model change, no migration, no async/race surface. `stage != discovery` defines "connected" the same way the existing disconnect-button gate does (line 75), so the indicator is consistent with the rest of the header.

## Non-blocking observations

1. **Hardcoded `Colors.white` assumes a dark header background.** The dim color `Colors.white.withValues(alpha: 0.3)` is fixed regardless of theme, whereas the adjacent battery icon uses the default theme-driven icon color. Under a light theme the dim Bluetooth icon would be near-invisible and would not track the battery icon. This matches the spec note and the file already hardcodes `Colors.red` for disconnect, so it is consistent with local style — flagged only for awareness.
2. **Connecting state stays dim by design.** While connecting, `stage` is still `discovery` (only `isConnecting` flips), so the icon remains dim until the stage advances to `impedance`. This is the intended behavior per the note, not a bug.

REVIEW_PASS
