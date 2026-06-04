# Plan Review: Add `impedanceOhm` to `BciChannelQualityDTO` and mapper

**Plan:** `08-add-impedanceohm-to-bcichannelqualitydto-and-mapper.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

All claims in the plan were checked against the actual source files:

| Claim | Verified |
|-------|----------|
| `BciChannelQualityDTO` carries only `channelName` + `quality` | ✅ Confirmed (`packages/bci_module/lib/src/BciPairing/Models/BciChannelQualityDTO.dart`) |
| Mapper uses inline `channels.map((c) => BciChannelQualityDTO(...))`, not a `mapChannel` helper | ✅ Confirmed (`lib/BciModule/BciChannelQualityMapping.dart:15-22`) |
| Domain field `BciChannelQuality.impedanceOhm` is `double` (non-nullable), not `int` | ✅ Confirmed (`lib/Bci/Models/BciChannelQuality.dart:13`) |
| Constructor file path | ✅ Correct |
| Mapper file path | ✅ Correct |

## Context Gates

- **Architecture:** The change respects the module boundary documented in `CLAUDE.md` — the DTO lives in the standalone `packages/bci_module/` package and the concrete mapper in `lib/BciModule/` bridges domain → DTO. Adding a field to the DTO and populating it in the mapper does not introduce any reverse dependency (package still imports nothing from `lib/`). No boundary violation. WARN: no `.ai-factory/ARCHITECTURE.md` boundary conflict found.
- **Rules:** Plan output is English, no proto changes (BCI quality is a domain/DTO concern, not a `.proto` contract), no manual `pubspec.yaml` edits. Compliant.
- **Roadmap:** Plan derives from spec note `74-bci-channel-quality-impedance-dto.md`; linkage is explicit. OK.

## Findings

### Correctness
- The decision to declare `final double? impedanceOhm` instead of the spec's `int?` is **correct** and well-justified — it avoids a lossy `double → int` truncation and a type mismatch against the domain model. Good catch by the plan author.
- Keeping the field **optional (non-`required`)** is necessary: the only constructor call site is the mapper, but making it required would still be a needless tightening. Verified there is exactly **one** real call site (`BciChannelQualityMapping.dart`); the other grep hits are the spec note and the plan itself. No call sites break.
- Parameter ordering note ("after the existing `required` params") is valid Dart — optional named params can coexist with required named params in any order, but placing it last is conventional and harmless.

### Architecture / Best Practices
- The plan correctly overrides the stale spec note (`mapChannel` helper that does not exist) with the actual inline-map implementation. This is the right call.
- No migration concerns (no DB schema, no Drift table, no proto involved — this is a pure in-memory DTO field).

### Security / Performance
- None applicable. Pure value pass-through, no I/O, no user input.

## Minor Observations (non-blocking)

1. **Semantic nullability gap:** The DTO field is nullable but the domain always supplies a non-null `double`. So `impedanceOhm` will in practice never be null today. This is intentional per the plan (future hardware may not report it), but downstream UI consumers must be written to handle `null`. The plan already flags that `BciImpedanceSection` is a separate future task — acceptable.
2. **Verification step is sound:** Running `/usr/local/bin/flutter analyze` matches the recorded preference for the Flutter full path. Consider analyzing both the package (`packages/bci_module`) and the app root, since the field is added in the package but consumed in `lib/` — the plan's "affected packages" wording already covers this.

## Positive Notes
- Spec deviations are explicitly documented with reasoning rather than silently applied.
- Type-safety reasoning (`double?` vs `int?`) is exactly the kind of codebase-grounded correction a plan should make.
- Scope is tightly bounded (two edits, no UI, no tests requested) and the task dependency (Task 2 depends on Task 1) is correctly ordered.

PLAN_REVIEW_PASS
