# Code Review (round 2) — Bio id-routing red tests (TDD-first)

Re-reviewed `git diff HEAD` / `git status` in full. Since review-1 the only code change is an
improved `test/Biometrics/biometric_stream_id_routing_test.dart` (265 → 287 lines). The production
seam (`lib/Biometrics/BiometricStreamClient.dart`) and the two other test files
(`breath_module_state_channel_test.dart`, `module_instruction_stream_test.dart`) are byte-identical
to the versions verified in review-1. Artifact files (plan `.md`/`.json`, plan-review, review-1) are
non-code and not reviewed.

## Both review-1 findings resolved

1. **Crash-red → clean-red (tests #2/#3).** Both now assert `expect(stub.callCount, greaterThan(0),
   reason: …)` before touching `stub.latest`, so the RED state surfaces as a readable expectation
   failure with an explanatory reason instead of a `StateError: No element` from `connections.last`.
   The regression-catching property is preserved: a bio impl that still clears on child end (or an
   unwired seam) opens no stream and fails at that guarded assertion.

2. **“Replay ring emptied” clause now directly exercised (test #3).** The test buffers `sample(1)`
   into the ring while the stream is open-but-not-ready, emits `rootIdChanges(null)`, then injects
   `ready` on the still-open connection and asserts `batches` is empty — proving the ring was cleared
   on reset, not merely that “nothing new was sent.” A partial impl that clears the id but leaks the
   ring would drain `sample(1)` here and fail. This closes the coverage gap against note 23.

## Verification of the improved test #3

Traced under both states:
- **Current code (RED):** `rootIdChanges('root-1')` is a no-op → `sendBatch` gate returns
  (`_currentSessionId == null`) → `callCount == 0` → fails at the guarded `greaterThan(0)` assertion
  with its reason. Clean RED, no crash. ✔
- **Under note 17 (GREEN):** id sourced from root → stream opens, `sample(1)` buffers in the ring →
  `rootIdChanges(null)` clears id + ring → `injectReady()` drains nothing → `batches` empty ✔;
  `sendBatch(sample(2))` no-ops (id cleared) → `callCount` unchanged ✔. Robust to whether note 17
  also tears the sink down on root-gone (either way `batches` stays empty and `callCount` is stable). ✔

## Re-confirmed from review-1 (unchanged files)

- **Seam:** additive optional `Stream<String?>? rootIdChanges`, null-safe `?.listen`, cancelled in
  `dispose()`, `_onRootIdChanged` a no-op; `_currentSessionId`/`_sessionConfirmed`/send path untouched
  → byte-identical current behavior; `App.dart` and existing suites compile/pass unchanged. ✔
- **Phase-decoupling guard** (breath channel): emits marker under `child-breath`, asserts
  `== 'child-breath'` and `!= 'root-1'`; GREEN now and unaffected by note 17. ✔
- **Late `SESSION_NOT_FOUND`** (instruction stream): `error` onData frame hits the log-only branch
  (no `disconnect`/`scheduleReconnect`), subsequent `emit` still reaches the wire; proto type
  `StreamResponse.error: StateErrorEvent` and the `show` import compile without ambiguity. GREEN. ✔

## Note (not a finding)
Per the TDD-first design, this milestone intentionally commits RED tests; `flutter test` stays red on
this branch until note 17 lands. That is the deliverable, not a regression.

No outstanding issues.

REVIEW_PASS
