# Code Review: BCI data screen header — battery + channel dots together on left with pill background

## Scope
One file changed: `packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart` (plus plan/plan-review artifacts, not code).

## Summary
The change reorders the header `Row` from `[battery] [Spacer] [channelRow]` to `[battery] [SizedBox(8)] [pill(channelRow)] [Spacer]`, wrapping the dots in a rounded `cardColor` pill. Implementation matches the plan exactly.

## Correctness analysis

- **Widget reuse**: `channelRow` is declared (`final Widget channelRow;`) and assigned in both branches before the `return`, then reused unchanged inside the new `Container`. No null/scope/definite-assignment issue — both `if`/`else` paths assign it.
- **Theme access**: `Theme.of(context).cardColor` uses the `context` from `build(BuildContext context, WidgetRef ref)`. In scope and valid.
- **Layout / vertical alignment**: `Container(height: 22)` with no `alignment` forwards a tight height constraint to its child `Row` (`MainAxisSize.min`, default `crossAxisAlignment.center`), centering the 8×8 dots vertically inside the pill. The outer `Row` defaults to `crossAxisAlignment.center`, so the 22px pill and the battery row (16px icon + text baseline) align centered. Consistent and correct.
- **Overflow**: trailing `Spacer()` absorbs remaining horizontal space; battery row and pill both use `MainAxisSize.min`. No unbounded-width or overflow risk.
- **Disconnected state**: pill is now always rendered, showing the 4 grey placeholder dots at 0.3 opacity inside the `cardColor` background. This is the intended behavior per the spec's verify section.
- **Unchanged internals**: dot size (8×8) and inter-dot spacing (`SizedBox(width: 4)`) are untouched, as required.
- **Doc comment**: updated to reflect the new grouped-left layout — accurate.

## Security
No security surface — pure presentation widget, no I/O, no user input, no auth.

## Runtime risks
None identified. No migrations, async, state, or type concerns; this is a static layout change to const-heavy widget tree.

REVIEW_PASS
