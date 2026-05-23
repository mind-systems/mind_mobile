# Code Review: Implement BciDataScreen + widgets

**Branch:** `bci-integration`
**Plan:** `.ai-factory/plans/58-implement-bcidatascreen-widgets.md`
**Files reviewed:**
- `packages/bci_module/lib/bci_module.dart`
- `packages/bci_module/lib/src/BciData/BciDataScreen.dart`
- `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
- `packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart`
- `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart`
- `packages/mind_l10n/lib/l10n/app_en.arb`, `app_ru.arb`, and the three regenerated `app_localizations*.dart` files

`flutter analyze` on the two changed packages: **No issues found.**

---

## Findings

### 1. `BciDataHeader` GestureDetector does not cover the full header — center gap is dead-tap

`BciDataHeader` (`packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart:56–86`) wraps a `Row` containing a battery column, a `Spacer()`, and the impedance dots in a `GestureDetector(onTap: vm.onHeaderTap, ...)`. No `behavior:` is set, so it defaults to `HitTestBehavior.deferToChild`. `Spacer()` produces a transparent `Expanded` with no child, which does not register hits. Result: tapping the empty center band between the battery percent and the impedance dots is a no-op even though the user perceives the whole row as one tappable target.

Notes file (`.ai-factory/notes/24-bci-data-screen.md:241–243`) explicitly states "GestureDetector wrapping **full-width row**. Tap calls `coordinator.openPairing()`." — the intent is full-width.

**Fix:** add `behavior: HitTestBehavior.opaque` to the `GestureDetector`. (Translucent works too if there is ever a need to layer a hit target above another widget, but `opaque` matches intent here.)

This is the main behavioral bug in the change.

---

### 2. Disconnected-state placeholder dots are red, not neutral

In `BciDataHeader.build()` (lines 29–37), when `!state.isConnected || state.channels.isEmpty`, the placeholder list is built with `quality: BciSignalQuality.poor`, which `_impedanceColor` maps to red `0xFFF88D8D`. The placeholder row is then wrapped in `Opacity(opacity: 0.3, ...)`.

The result is four faded-red dots whenever the device is disconnected. Two concerns:

- **UX semantics:** the user can read this as "all channels in poor signal" rather than "no device". `BciImpedanceSection` (`packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart:73`) deliberately uses `Colors.grey.shade400` for the same placeholder concept — neutral grey, no signal-quality coloring.
- **Spec match:** the notes only say "all dots render at 0.3 opacity" — color is unspecified, but the precedent in the codebase (and good UX) is grey.

**Fix:** render the placeholder dots with a neutral grey (`Theme.of(context).colorScheme.outlineVariant`, or `Colors.grey.shade400` to match `BciImpedanceSection`) instead of looping through `_impedanceColor(BciSignalQuality.poor)`. Cleaner still: build the placeholder row from a separate code path that does not allocate `BciChannelQualityDTO` instances with a misleading `poor` quality value.

Bonus: constructing `BciChannelQualityDTO(channelName: '', quality: BciSignalQuality.poor)` for purely visual placeholders puts a domain-DTO with semantically wrong state into the widget tree — a small smell.

---

### 3. Placeholder dot count is hard-coded to 4 but real channels can be a different count

When the device is connected, `state.channels` drives both the count and the colors of dots. When disconnected, the code generates exactly 4 placeholder dots. If the actual `BciDeviceProvider` ever reports a different channel count (3, 5, 6 — Neiry hardware varies), the header will visually "jump" from 4 grey dots to N colored dots the moment connection succeeds.

`BciImpedanceSection` has the same constant (`placeholderCount = channels.length < 4 ? 4 - channels.length : 0`) and is therefore tolerant in only one direction. This is a pre-existing convention rather than a new defect, but the new code inherits the assumption verbatim. Not blocking — flagging for awareness.

---

### 4. Heart-rate row can horizontally overflow on small screens / large dynamic-text settings

`BciDataScreen.build()` (lines 52–68) builds the heart-rate row as a `Row` of `Icon + Text(label) + Text(value) + Text(unit)` with no `Flexible`/`Expanded` wrapper and no `overflow: TextOverflow.ellipsis` on the text spans. In English the texts are short ("Heart rate", "BPM"), in Russian "Пульс" and "уд/мин" are still short, but with a system-level large text scale (accessibility) or a narrow device the row can produce a yellow-and-black overflow stripe.

**Fix (defensive):** wrap the label `Text` in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`, or use `FittedBox(fit: BoxFit.scaleDown)` around the whole row.

Low severity — not a runtime crash, just a layout assertion in extreme conditions.

---

### 5. `BciMetricBar` opacity transition is not animated (small visual quirk)

`BciMetricBar` (`BciMetricBar.dart:34–50`) wraps `AnimatedContainer` inside an `Opacity` widget. When `value` transitions from a numeric value to `null` (or vice versa), the height animates smoothly, but the opacity flips abruptly between 0.3 and 1.0 in the same frame. With `AnimatedOpacity` (or moving the opacity into the `decoration` via `color.withOpacity(...)`) the two transitions would feel cohesive.

Minor polish — not a correctness issue.

---

### 6. `bci_module.dart` barrel — `BciChannelQualityDTO` continues to be sourced from `BciPairing/Models/`

This is the deferred cleanup the plan called out in its Context section. Recording it here only so the eventual `shared/` reorg has a hook: `BciDataHeader` adds a second cross-feature relative import (`../../BciPairing/Models/BciChannelQualityDTO.dart`), and `BciDataScreen` adds one for `BciSectionHeader`. When the move happens it will need to update three files (`BciDataState`, `BciDataHeader`, `BciDataScreen`) plus the `BciPairingState` import.

Not blocking; explicitly deferred by plan.

---

### 7. Sanity — runtime contract

`BciDataScreen` calls `ref.read(bciDataViewModelProvider.notifier)`, which throws `UnimplementedError` unless overridden in a `ProviderScope`. The plan correctly scopes the wiring (route, `BciModule.buildDataScreen`, ProviderScope override) to roadmap tasks 129/131. As of this branch, attempting to push to `BciDataScreen.path` would throw. This is expected and matches the plan scope — flagged only so the reviewer of the wiring PR remembers to add the override.

---

## Summary

The implementation faithfully tracks the (corrected) plan. The l10n keys are present in both ARB files and both generated locale files. `flutter analyze` is clean. The new screen and widgets follow the patterns established by `BciPairingScreen` / `BciImpedanceSection`.

The one substantive bug is **Finding #1** (GestureDetector behavior). **Finding #2** (red placeholder dots) is a UX issue worth fixing before merge. The rest are minor polish / deferred concerns.
