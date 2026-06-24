# connect() partial classifier-build leak (T3)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 2 — low-severity hardening.

## Key Findings

- In `connect()` (`lib/Bci/NeiryBciProvider.dart:165-193`), `_classifierSet = _classifierFactory.build(_device!)` (`:176`) builds the four native classifiers inside `NeiryClassifierSet`'s constructor initializer (`lib/Bci/Ports/NeiryClassifierSet.dart:23-27`: `NfbClassifier` → `CardioClassifier` → `EmotionsClassifier` → `MEMSClassifier`).
- If a **later** classifier construction throws, the constructor never returns, so `_classifierSet` is never assigned. The catch block's `_classifierSet?.dispose()` (`:180`) is then a **no-op** → the already-constructed earlier classifiers (each holding native resources) **leak**.

## Details

- Build defensively inside `NeiryClassifierSet`: construct the four classifiers in a body (not an initializer list) so that, if classifier *n* throws, the already-built classifiers `0..n-1` are disposed before rethrowing. The public surface (`NeiryClassifierSet(neiry.Device)`) stays the same; only the construction becomes failure-atomic.
- The provider's connect()-error path (`:178-189`) is unchanged — it already disposes `_classifierSet`, disconnects/disposes the device, and resets the locator; this task only fixes the *partial-construction* window the catch can't reach.

## Guards

- Behavior-preserving on the success path — same four classifiers, same order.
- Do not change the `ClassifierSet` interface or the factory shape (that is `[[169-bci-remove-rawdevice-downcast]]`).
- Single-resource scope; no queue/CONSTRAINT changes.

## Verify

- A fake/forced throw on the *k*-th classifier construction disposes the first *k-1* and rethrows; no leaked native classifier.
- Connect happy path unchanged; B1/B2 + classifier-port tests green.

**Done-when:** `NeiryClassifierSet` construction is failure-atomic (partial builds self-dispose), covered by a test, suites green.
