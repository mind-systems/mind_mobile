# Code Review: B2 · Characterization — full teardown chain (L1 + classifier-disposal ordering)

**Reviewed change:** one new test file, `test/Bci/neiry_bci_provider_full_teardown_test.dart` (782 lines). No production code touched. The other staged files are plan/plan-review artifacts (docs only).

**Risk level:** 🟢 Low — test-only addition, no production behavior change. Suite is green and faithful to the gate version.

## Verification performed
- `git status` / `git diff HEAD --stat`: the only code file is the new test; production `lib/Bci/NeiryBciProvider.dart` is unmodified (matches the plan's "read-only unless a red probe forces a gate fix" — no red probe occurred).
- Read the new test in full and cross-checked every fake and assertion against the actual provider teardown microtask (`_teardownAfterUnexpectedDrop`, `lib/Bci/NeiryBciProvider.dart:404-441`) and the cancel/dispose try/finally structure.
- **Ran the new suite:** `flutter test test/Bci/neiry_bci_provider_full_teardown_test.dart` → **6/6 passed** (3 swallowed-throw probes, 1 throwing-cancel probe, 2 ordering probes).
- **Ran the B1 contract suite:** `flutter test test/Bci/neiry_bci_provider_locator_device_races_test.dart` → **10/10 passed** — confirms the committed B1 file was not edited and stays green (plan's hard constraint).
- `flutter analyze` on the new file → 1 warning (see Finding 1).

## Correctness assessment (traced, all confirmed)
- **L1 swallowed-throw probes (classifier dispose / device disconnect / device dispose):** the provider wraps each in try/catch (`:424-428`, `:431-436`), so the throw is absorbed and the `finally` (`:437-439`) still reaches `_resetLocatorSession()` → recreate. Tests assert `createdCount == 2`, `l0.disposeCount == 1`, `liveCount == 1`, `assertNoOrphan()`. Correct, and the per-case `closeControllers()` cleanup matches exactly which controllers are left open (classifier-only / device-only), preventing un-closed-controller flakes. ✓
- **L1 throwing-cancel probe:** the cancels at `:412-421` are *not* individually wrapped, so a throwing `cancel()` short-circuits to the outer `finally` → recreate still reached, and the teardown microtask rejects unobserved. The zone-binding fix from plan-review #1 is correctly applied: `connect()` runs inside the same `runZonedGuarded` body as the drop, so the listener-time zone is the guarded zone and the unhandled rejection is captured into `asyncErrors`. The recreate invariant (`createdCount == 2`, `liveCount == 1`, no orphan) holds — so the gate version is correct and no in-task gate fix was needed. ✓
- **Ordering probes:** `_connectThenDropRunToCompletion` (all gates pre-completed) drains the entire microtask-based teardown in one event-loop pump; the recorded `order.steps` equals the canonical unit `[stopStream, cancelFanIn, classifierDispose, deviceDisconnect, deviceDispose, locatorDispose, locatorCreate]`. The connection sub is the first cancel (`:412`), so `cancelFanIn` correctly lands between `stopStream` and `classifierDispose`. The concurrent-disconnect variant asserts the drop sub-sequence is contiguous and uses the churn caveat (`liveCount <= 1` + `assertNoOrphan`) rather than a tight count — matching B1's handling of the same race. ✓
- **Behavioral, C1-safe assertions:** all assertions reference observable counts / step labels / wait-ordering; nothing couples to `_teardownComplete` or other gate field names, so the suite survives the C1 actor refactor as intended. ✓
- **`_ControllableCancelSubscription`** implements the full `StreamSubscription` surface (`cancel`, `onData`, `onError`, `onDone`, `pause`, `resume`, `isPaused`, `asFuture`) — compiles and delegates correctly; "throw after inner cancel" leaves no un-cancelled inner subscription. ✓

## Findings

### 1. (Minor / lint) Redundant non-null assertion — `flutter analyze` warning
`test/Bci/neiry_bci_provider_full_teardown_test.dart:97`
```dart
if (_orderSteps != null && _label.isNotEmpty) {
  _orderSteps!.add(_label);   // ← '!' is redundant
}
```
The `_orderSteps != null` guard already promotes the final field to non-null inside the block, so the `!` is unnecessary and `flutter analyze` flags it:
`warning • The '!' will have no effect because the receiver can't be null • unnecessary_non_null_assertion`.

Not a bug — behavior is identical — but it leaves a standing analyzer warning on an otherwise-clean file. Recommend changing to `_orderSteps.add(_label);`.

## Non-issues considered and cleared
- **Run-to-completion pump count (2 pumps):** the teardown chain is entirely microtasks with pre-completed completers, so it fully drains before the first zero-duration timer fires; 2 pumps is more than enough. Confirmed by the green ordering test.
- **Unhandled-error delivery timing in the cancel-throw probe:** relies on a fixed number of trailing `Future.delayed(Duration.zero)` pumps to let the rejection reach the zone handler. It passed deterministically here; if it ever flakes, the remedy is simply more trailing pumps. Acceptable.
- **Dangling un-cancelled subscriptions in the cancel-throw path:** their controllers are force-closed in cleanup (`device.closeControllers()` + `fakeSet.closeControllers()`); broadcast `close()` with live subs only fires no-op `onDone` (provider registers no `onDone`), so nothing leaks into adjacent tests.
- **Provider construction outside the guarded zone (cancel-throw test):** harmless — only `listen()` (inside `connect()`, inside the zone) and the event callback's zone matter for the `Future.microtask` binding.
- **Shared `order` list accumulating extra labels after `provider.dispose()`:** no test asserts ordering after dispose, so this is inert.

## Recommendation
Functionally correct, faithful to the gate version, and meets the milestone's done-when (suite green; B1 still green; assertions behavioral). The only actionable item is the trivial lint warning in Finding 1 — fix it to keep `flutter analyze` clean, then this is ready.
