## Plan Review

**Plan:** `32-add-neiry-kit-path-dep-lib-bci-domain-types-ibcideviceprovider.md` (rev 2)
**Risk Level:** 🟢 Low — all blockers from review 1 are resolved; remaining notes are stylistic.

### Context Gates

- **ARCHITECTURE.md** — PASS. `lib/Bci/` mirrors the existing module layout (`lib/BreathModule/`, `lib/User/`). All new files sit at the domain layer; they import only `dart:async` and `package:flutter/foundation.dart` (for `@immutable`) — fully compliant with the rule "Notifier and Repository must NOT import `flutter/` or `riverpod`" (this is even stricter — interface and models too).
- **RULES.md** — PASS. No Service / Notifier / Coordinator is introduced in this milestone, so the stateless-service and constructor-injection rules are not in scope. The interface contract is set up correctly for future implementers (concrete `NeiryBciProvider` will be constructor-injected per RULES.md).
- **ROADMAP.md** — PASS. Plan is the first unchecked item under "Phase 17 — BCI Device Pairing". Every detail in the roadmap line (field names, enum values, sealed subtypes, method signatures, the explicit "`IndividualNfbData` must not leak into domain" rule, the "scan returns Stream<List<BciDeviceInfo>>" choice) is honored verbatim by Tasks 3–7.

### Review-1 Follow-ups — All Addressed

| Review-1 issue | Status in rev 2 |
|---|---|
| Streams declared as fields would force setters | ✅ Task 7 now mandates `Stream<X> get name;` with explicit rationale |
| SDK lower-bound mismatch (`^3.9.2` vs `^3.11.0`) | ✅ Task 1 has a precondition section with a verify-and-bump fallback |
| "Mirrors `BreathSessionNotifierEvent`" framing was inaccurate | ✅ Task 6 now reads "a stricter style than the existing… we are not literally mirroring that file" |
| `dispose()` semantics undocumented | ✅ Task 7 now requires dartdoc: post-dispose streams closed, calls undefined, callers reconstruct |

### Critical Issues

None.

### Non-Critical Notes

**1. `abstract interface class` fallback wording (Task 7)**

The plan says: "or `abstract class` if the project's lint config doesn't permit `abstract interface class` — check `analysis_options.yaml` if needed". This is slightly misleading — `abstract interface class` is a Dart 3 *language* feature, not a lint. `analysis_options.yaml` only sets `flutter_lints` + `errors: file_names: ignore`, so the syntax will work regardless. The fallback escape hatch is harmless but could be confidently dropped. Not a blocker.

**2. `BciDeviceInfo` lacks `==`/`hashCode` (Task 3)**

The plan doesn't ask for value-equality. This mirrors `neiry_kit`'s `DeviceInfo` and the existing project models (`BreathSession`), so it's consistent. Worth noting only because downstream `BciDeviceManager` will likely need to de-dup scanned devices by serial — but that can be handled at the manager layer without forcing equality onto the DTO. Acceptable as-is.

**3. `BciCalibrationFailed.reason: String` discards `NfbCalibrationFailReason`**

Same flag as review 1 (point 6) — `neiry_kit` exposes a structured `NfbCalibrationFailReason` enum that gets flattened to a free-form String at the domain boundary. The plan acknowledges this and notes a future refactor may introduce a domain enum. Acceptable for the foundation milestone.

**4. iOS `pod install` deferral (Task 2)**

The plan now explicitly defers build-level validation to "the milestone that first instantiates a concrete provider". This is the right call — adding a build step here would slow the loop and the foundation code has zero usage to exercise. Resolved.

**5. Phase-2 dependency on Task 2 (Tasks 3–6)**

Same observation as review 1 (point 5) — Tasks 3–6 import nothing from `neiry_kit`, so technically they could land before Task 2. Keeping the dependency is still the safer sequencing call (prevents a state where the project compiles but `pubspec.lock` is out of date). Non-issue.

### Positive Notes

- Stream-getter syntax is now spelled out with the exact failure mode it prevents — anyone implementing this can't accidentally fall back to abstract fields.
- The SDK-bump precondition reads correctly: verify first, bump only if resolution actually fails. This avoids gratuitously bumping the host's lower bound when the dev machine already satisfies both constraints.
- The class-level dartdoc requirement on `IBciDeviceProvider` (Task 7) and the dartdoc on `BciConnectionState` distinguishing it from `NeiryConnectionState` are exactly the preventative comments that pay off when a new contributor wonders why two enums exist.
- Domain-isolation rule ("`IndividualNfbData` must NOT leak into the domain") is restated at the per-task level (Task 6) — it would be easy to miss otherwise.
- Commit plan is clean (3 logical commits aligned with the 3 phases). The "Add Bci domain models" commit bundles all 4 models, which is correct — they're a coherent type family and reviewing them together is more useful than 4 separate one-file commits.
- Signature ordering in Task 7 (scan → connect/disconnect → observation streams → commands → dispose) reads top-to-bottom as a device lifecycle.

PLAN_REVIEW_PASS
