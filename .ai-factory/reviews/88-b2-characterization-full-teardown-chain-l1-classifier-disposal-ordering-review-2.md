# Code Review (round 2): B2 · Characterization — full teardown chain (L1 + classifier-disposal ordering)

**Reviewed change:** one new test file, `test/Bci/neiry_bci_provider_full_teardown_test.dart`. No production code touched. Other staged files are plan / plan-review / round-1 review artifacts (docs only).

**Risk level:** 🟢 Low — test-only addition, no production behavior change.

## What changed since round 1
Round 1 raised a single, non-blocking finding: a redundant non-null assertion at `:97` (`_orderSteps!.add(_label)` → `unnecessary_non_null_assertion`). That is now fixed — the line reads `_orderSteps.add(_label);` (the preceding `_orderSteps != null` guard already promotes the final field). No other lines changed.

## Verification performed
- `git status`: still only the new test file as the code change; `lib/Bci/NeiryBciProvider.dart` remains unmodified (no red probe forced a gate fix).
- **`flutter analyze test/Bci/neiry_bci_provider_full_teardown_test.dart` → "No issues found!"** — the round-1 warning is resolved; the file is clean.
- **Re-ran `flutter test test/Bci/neiry_bci_provider_full_teardown_test.dart` → 6/6 passed** (3 swallowed-throw L1 probes, 1 throwing-cancel L1 probe, 2 ordering probes).
- B1 contract suite (`neiry_bci_provider_locator_device_races_test.dart`) was confirmed green and untouched in round 1; the new file did not change in any way that could affect it.

## Correctness assessment (carried from round 1, re-confirmed)
- **L1 swallowed-throw probes:** the provider's try/catch around classifier dispose (`:424-428`) and device disconnect/dispose (`:431-436`) absorbs the throw; the `finally` (`:437-439`) still reaches `_resetLocatorSession()` → recreate. Asserts `createdCount == 2`, `l0.disposeCount == 1`, `liveCount == 1`, `assertNoOrphan()`, with per-case `closeControllers()` cleanup matching exactly which controllers are left open. ✓
- **L1 throwing-cancel probe:** cancels at `:412-421` are not individually wrapped, so a throwing `cancel()` short-circuits to the `finally` → recreate still reached; the unobserved teardown microtask rejects. `connect()` runs inside the same `runZonedGuarded` body, so the listener-time zone captures the rejection into `asyncErrors`. Recreate invariant holds → gate version correct, no in-task fix needed. ✓
- **Ordering probes:** pre-completed gates drain the microtask-based teardown in one pump; recorded `order.steps` equals the canonical unit `[stopStream, cancelFanIn, classifierDispose, deviceDisconnect, deviceDispose, locatorDispose, locatorCreate]`. The concurrent-disconnect variant asserts the drop sub-sequence is contiguous and uses the churn caveat (`liveCount <= 1` + `assertNoOrphan`). ✓
- **C1-safe assertions:** all assertions reference observable counts / step labels / wait-ordering; none couple to `_teardownComplete` or other gate field names. ✓
- **`_ControllableCancelSubscription`** implements the full `StreamSubscription` surface and "throws after inner cancel," leaving no un-cancelled inner subscription. ✓

## Findings
None. The round-1 finding is resolved; analyzer is clean; both suites are green; the change is faithful to the gate version and meets the milestone's done-when.

REVIEW_PASS
