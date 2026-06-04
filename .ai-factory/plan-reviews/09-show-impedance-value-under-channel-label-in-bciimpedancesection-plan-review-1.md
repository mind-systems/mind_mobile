# Plan Review: Show impedance value under channel label in BciImpedanceSection

**Plan:** `09-show-impedance-value-under-channel-label-in-bciimpedancesection.md`
**Risk Level:** 🟡 Low–Medium

## Verified Against Codebase

| Claim in plan | Status |
|---|---|
| File path `packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart` | ✅ Correct |
| Per-channel `channels.map((ch) => Column(...))` block at lines 45–62 | ✅ Exact match |
| `Text(ch.channelName, ...)` at lines 57–60 | ✅ Exact match |
| Placeholder block `List.generate(placeholderCount, ...)` at lines 63–80 | ✅ Exact match |
| `BciChannelQualityDTO.impedanceOhm` already exists, no model change needed | ✅ Confirmed (`Models/BciChannelQualityDTO.dart:6`) |
| `.withValues(alpha:)` is the project-standard API (not `.withOpacity()`) | ✅ Confirmed in use (`mind_ui/AppTheme.dart`, `breath_module`, `meditation_module`, etc.) |

The file references and structural assumptions are all accurate — unusually precise for a plan.

## Context Gates

- **ARCHITECTURE.md** — No boundary violation. The change is confined to the presentation package and consumes an existing DTO field; no domain model leaks across the module boundary. ✅
- **RULES.md** — Not present at the relevant path; no explicit convention checked. WARN (optional file absent).
- **ROADMAP.md** — This is a small UI follow-up to phase 08 (impedance plumbing). Roadmap linkage is implicit via notes 74/75; acceptable for a UI-only task.

## Critical Issues

None blocking.

## Issues to Address Before Implementing

### 1. "Integer" intent vs. `double` reality — output will render decimals (Medium)

The plan's Context says *"Display the raw **integer** impedance value"*, and the title says "impedance value". But `BciChannelQualityDTO.impedanceOhm` is a **`double?`**, sourced from a `double` in the domain model (`lib/Bci/Models/BciChannelQuality.dart:13`), which is populated directly from the device's `r.values[i]` (`lib/Bci/NeiryBciProvider.dart:282,293`) with no rounding.

`ch.impedanceOhm?.toString()` on a `double` produces decimal output:
- `1000.0` → `"1000.0"`
- `523.7` → `"523.7"`

So the rendered text will **not** be an integer, contradicting the stated intent. The phase-08 review explicitly flagged that the field was deliberately kept `double?` (not `int?`) to avoid lossy truncation — so this plan inherits a `double` and the "integer" wording is now stale.

**Decision needed:** if the intent is genuinely an integer display, use `ch.impedanceOhm?.round().toString()` or `ch.impedanceOhm?.toStringAsFixed(0)`. If decimals are acceptable, the plan's wording should drop "integer" to avoid implementer confusion. Recommend `.toStringAsFixed(0)` to match the "integer" intent without a separate `round` call.

### 2. Vertical alignment with placeholders / null-value columns (Low)

The new value `Text` adds a second line of height to real channels that have a non-null impedance. Placeholder columns (`const Text(' ')`) and real channels with a null impedance render only one text line. Because a `Row`'s default `crossAxisAlignment` is `center`, columns of differing heights center-align — meaning the **circles can become vertically misaligned** across columns when a mix of value-present and value-absent/placeholder columns coexists (i.e. `channels.length` is 1–3, or some channels report null).

In practice channels usually arrive as a full set of four with values, so this is a minor visual edge case rather than a correctness bug. If pixel-perfect circle alignment matters, consider reserving a fixed-height slot for the value line (matching the existing `const Text(' ')` placeholder approach) instead of collapsing to zero height. Worth a one-line note in the plan; not a blocker.

## Positive Notes

- Line numbers and the target widget tree are cited exactly — implementation will be unambiguous.
- Correctly identifies that the placeholder block has no DTO and must stay untouched.
- Correctly mandates `.withValues(alpha:)` over the deprecated `.withOpacity()`, consistent with the rest of the codebase.
- Null handling (empty string for null) is sensible and avoids an extra `SizedBox`.

## Recommendation

Resolve issue #1 (integer formatting wording / `toStringAsFixed(0)`) before implementing — it is a one-line decision that changes the output. Issue #2 is optional polish. With #1 clarified, the plan is sound.
