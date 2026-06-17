# Plan Review: NfbCalibrationRepository tests

**Plan:** `.ai-factory/plans/36-nfbcalibrationrepository-tests.md`
**Target:** `lib/Bci/NfbCalibrationRepository.dart` → `test/Bci/nfb_calibration_repository_test.dart`
**Risk Level:** 🟢 Low — plan is accurate against the actual code; only minor implementer notes.

## Verification against the codebase

I read the source the plan targets and cross-checked every test case:

- `NfbCalibrationRepository` (`lib/Bci/NfbCalibrationRepository.dart`) — `history()`, `latestValid()`, `record()`, `refreshFromServer()` all match the plan's described behavior.
- `NfbCalibrationData` (`lib/Bci/Models/NfbCalibrationData.dart`) — `toJson`/`fromJson` confirmed.
- `NfbCalibrationGrpcApi` (`lib/Bci/NfbCalibrationGrpcApi.dart`) — `record()` / `list()` signatures confirmed.
- `record(...)` already exposes `@visibleForTesting bool awaitApiSync = false` (ROADMAP line 105 — already implemented), and `meta` is a direct dep. The test plan's awaited-sync assertions are therefore wireable today.
- Fake convention: the codebase fakes via `implements` on the implicit interface (e.g. `test/Core/AppSettings/app_settings_repository_test.dart`). `FakeNfbCalibrationGrpcApi implements NfbCalibrationGrpcApi` is valid — the only public members are `record`/`list`, and the private `_client` field is not part of the interface, so no real `NfbCalibrationServiceClient` is needed.

### Test-case accuracy (all confirmed correct)

- **history()** — empty on missing key (l24), non-JSON (catch l32), non-List (l27); preserves order; `whereType<Map<String, dynamic>>()` skips non-maps (l29); `individualPeakFrequency ?? individualFrequency` fallback (fromJson l67).
- The case *"empty list when an entry has an unparseable calibratedAt"* is subtle but correct: `DateTime.parse` throws **inside `.map().toList()`**, which propagates to the outer `catch` — so the **entire** list returns empty (not a per-entry skip). The plan's wording matches this.
- **latestValid()** — first `isValid` entry in list order, else null (l37–42). Correct.
- **record()** — prepend `[data, ...existing]` (l61), `sublist(0, 20)` drops the tail/oldest (l62–64), correct key, round-trip. Correct.
- **record() sync** — `catchError` is attached before the `awaitApiSync` branch, so a failing API call resolves the awaited future *normally* (no rethrow). The plan's *"not rethrow when awaitApiSync: true"* expectation is right.
- **refreshFromServer()** — `sublist(0, 20)` truncation, overwrite, and the catch-and-log-no-write path (cache unchanged on `list()` throw, l50–52). Correct.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): WARN — none. Test-only plan; domain layer is pure Dart, no boundary impact.
- **Rules** (`.ai-factory/RULES.md` present): WARN — none. The three rules concern Module Services / App.dart / constructor DI; none apply to a repository unit test.
- **Roadmap** (`.ai-factory/ROADMAP.md` present): The prerequisite (`awaitApiSync` testability hook, line 105) is done. This plan is the natural follow-up under the "Test Infra" section. A companion note already exists at `.ai-factory/notes/92-test-plan-nfb-calibration-repository.md` — implementer should reconcile with it to avoid divergence.

## Minor Notes (non-blocking)

1. **`test/Bci/` directory does not exist yet.** Other suites live under `test/Biometrics/`, `test/Core/`, etc. The implementer must create `test/Bci/`. Trivial, but call it out so it isn't assumed present.
2. **Fake `list()` must include the optional named param** `{int limit = 50}` to satisfy the implicit interface signature `Future<List<NfbCalibrationData>> list(String serial, {int limit = 50})`. The plan's Fake description omits it; an exact-signature match is required to `implements`.
3. **The `NfbCalibrationData` factory helper should default `failReason`.** `fromJson` reads `json['failReason'] as String` (non-nullable) — any seeded raw JSON for the valid-array cases must include `failReason`, and the helper's `toJson()` output must carry it. The plan lists `calibratedAt`, `isValid`, and numeric fields as overridable but doesn't mention `failReason`; give it a sane default (e.g. `"none"`).
4. **Async fire-and-forget test:** the deferrable `record()` (Completer-backed) approach is correct. Ensure the test completes/cleans the Completer at end so it doesn't leak a pending future across tests; consider `await pumpEventQueue()` only where ordering must be asserted.

## Positive Notes

- Every test case maps to a real, reachable code path — no speculative behavior, no tests for branches that don't exist.
- The plan correctly distinguishes the awaited vs fire-and-forget sync paths and leverages the already-shipped `awaitApiSync` hook rather than relying on artificial delays.
- Directly seeding prefs via `_keyFor(serial)` to exercise malformed-JSON and missing-key fallbacks is the right approach (these can't be produced through `toJson`).
- Phasing (history → latestValid → record → refresh) is logically ordered and independently checkable.

The plan is accurate, complete for the four public methods, and aligned with project test conventions. The minor notes are implementer guidance, not corrections.

PLAN_REVIEW_PASS
