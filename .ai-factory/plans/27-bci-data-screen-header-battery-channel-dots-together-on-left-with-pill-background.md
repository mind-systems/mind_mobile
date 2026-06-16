# Plan: BCI data screen header — battery + channel dots together on left with pill background

## Context
Group the channel-quality dots next to the battery indicator on the left of the BCI data screen header, wrapping the dots in a rounded `cardColor` pill instead of pushing them to the right edge.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Header rearrange

- [x] **Task 1: Move channel dots into a left-side pill next to the battery**
  Files: `packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart`
  In `BciDataHeader.build`, the outer `Row` (lines 77–98) currently lays out `[battery Opacity] [Spacer] [channelRow]`. Reorder it to `[battery Opacity] [SizedBox(width: 8)] [pill] [Spacer]` so the dots sit immediately to the right of the battery.
  - Keep the existing `channelRow` widget (real colored dots when `showRealDots`, grey 0.3-opacity placeholders otherwise) and its internal dot size (8×8) and spacing (`SizedBox(width: 4)`) exactly as-is.
  - Replace `const Spacer(), channelRow,` with:
    ```dart
    const SizedBox(width: 8),
    Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: channelRow,
    ),
    const Spacer(),
    ```
  - Use `Theme.of(context).cardColor` for the pill background — the same token `SessionBottomBar` uses on the breath screen; no new theme token. `context` is already available from `build(BuildContext context, WidgetRef ref)`.
  - Update the class doc comment (lines 18–19) to reflect that battery and channel dots now sit together on the left.
  - Note: the spec note references `BciDataScreen.dart`, but the header widget actually lives in this `Views/BciDataHeader.dart` file — apply the change here.

## Notes
Single-file, single-task change → one commit at the end. No commit plan needed.
