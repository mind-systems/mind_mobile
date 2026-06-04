# Plan Review (2): Show impedance value under channel label in BciImpedanceSection

**Plan:** `09-show-impedance-value-under-channel-label-in-bciimpedancesection.md`
**Risk Level:** 🟢 Low

## Verified Against Codebase

| Claim in plan | Status |
|---|---|
| File path `packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart` | ✅ Correct |
| Per-channel `channels.map((ch) => Column(...))` block at lines 45–62 | ✅ Exact match |
| `Text(ch.channelName, ...)` at lines 57–60 | ✅ Exact match |
| Placeholder block `List.generate(placeholderCount, ...)` at lines 63–80 | ✅ Exact match |
| `BciChannelQualityDTO.impedanceOhm` is `double?`, already exists, no model change | ✅ Confirmed (`Models/BciChannelQualityDTO.dart:6`) |
| `.withValues(alpha:)` is the project-standard API | ✅ Confirmed in use (`HomeModule/.../SuggestionsCard.dart`, `meditation_module`, etc.) |
| Proposed `style` chain (`labelSmall?.copyWith(color: labelSmall?.color?.withValues(alpha: 0.5))`) type-checks | ✅ `labelSmall` is `TextStyle?`, `.color` is `Color?` — all null-aware, valid |

File references and structural assumptions remain exact.

## Resolution of Review-1 Findings

- **Issue #1 (integer intent vs `double` reality):** Resolved. The plan now mandates `.toStringAsFixed(0)` and includes an explicit rationale (rounds for display without mutating the `double`). The stale "integer" wording in the Context has been replaced with "as a whole number." ✅
- **Issue #2 (vertical alignment with placeholder / null columns):** Resolved as documentation. The plan adds a "Notes / Known limitations" section that accurately describes the `crossAxisAlignment: center` mix-height edge case and consciously defers a fixed-height slot, keeping the change a single-file, single-widget edit per spec. ✅

## Context Gates

- **ARCHITECTURE.md** — No boundary violation. Change is confined to the presentation package and consumes an existing DTO field; no domain model crosses the module boundary. ✅
- **RULES.md** — Not present at the relevant path. WARN (optional file absent), non-blocking.
- **ROADMAP.md** — Small UI follow-up to phase 08 (impedance plumbing). Roadmap linkage is implicit; acceptable for a UI-only cosmetic task. WARN, non-blocking.

## Critical Issues

None.

## Issues to Address Before Implementing

None blocking. One optional observation:

- **Logging setting (minor):** Settings declare `Logging: minimal`, but a pure display-text widget has no meaningful log point. No action expected — flagged only so the implementer doesn't add log noise to satisfy the setting.

## Positive Notes

- Both review-1 findings were addressed substantively, not just acknowledged.
- Line numbers and the target widget subtree are cited exactly — implementation is unambiguous.
- Correctly leaves the placeholder block untouched (no DTO there).
- Mandates `.withValues(alpha:)` over deprecated `.withOpacity()`, consistent with the codebase.
- Null handling (empty string → zero height, no extra `SizedBox`) is clean and reasoned.

## Recommendation

The plan is accurate, scoped, and self-consistent. Both prior-review issues are resolved. Ready to implement.

PLAN_REVIEW_PASS
