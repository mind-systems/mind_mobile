# Code Review 3: Wire NfbClassifier, CardioClassifier, EmotionsClassifier in NeiryBciProvider

**Plan file:** `.ai-factory/plans/54-wire-nfbclassifier-cardioclassifier-emotionsclassifier-in-neirybciprovider.md`

**Changed files** (`git diff HEAD`):
- `lib/Bci/IBciDeviceProvider.dart` — unchanged since review-1
- `lib/Bci/NeiryBciProvider.dart` — F6 from review-2 addressed
- Plan / plan-review / review-1 / review-2 artifacts (new)

## Delta vs review-2

| Finding | Status | Evidence |
|---|---|---|
| F6 — Error-stream subs missing `onError:` | **Fixed** | Both `_nfbErrorSub` (lines 186–190) and `_emotionsErrorSub` (lines 203–207) now pass `onError: (Object e) => logPrint('… errorStream error: $e')`, matching the convention used on every other `.listen()` call in the file. |

All findings from review-1 (F1–F5) remain resolved.

## Per-file verification

### `lib/Bci/IBciDeviceProvider.dart`
Three abstract getters + three `Models/` imports added in alphabetical order. No defects.

### `lib/Bci/NeiryBciProvider.dart`

- **Fields (lines 28–51):** Three classifier fields, three broadcast controllers, five typed subscription fields (state subs for NFB/Cardio/Emotions, error subs for NFB and Emotions — Cardio's dartdoc confirms it has no `errorStream`). Stream element types match the neiry_kit declarations.
- **Getters (lines 70–77):** Three `@override` getters delegate to their respective controllers.
- **`connect()` (lines 134–161):** Classifiers instantiated after `_device!.start()` succeeds. Catch block disposes classifiers first (per-classifier `try { … } catch (_) {}`), then disposes the device inside its own `try { … } catch (_) {}`. Each field is nulled immediately after its disposal attempt, then `_device = null`, then `rethrow`. Ordering is consistent with the normal teardown path.
- **`_subscribeDeviceStreams()` (lines 163–209):** Six listener calls (3 device + 3 classifier state + 2 classifier error). All carry `onError → logPrint`. Comment on lines 179–180 documents the non-null invariant.
- **Mapping handlers (lines 254–284):** Direct field-to-field copies. `timestamp` dropped. No filtering — downstream `BciDataService` will gate cardio.
- **`_cancelDeviceSubscriptions()` (lines 313–349):** Cancels all five new subscriptions (3 state + 2 error), then disposes the three classifiers with `try { … } catch (e) { logPrint(…) }`, nulling each field after its disposal attempt.
- **`_doDispose()` (lines 374–392):** Calls `_cancelDeviceSubscriptions()` first; then disposes the device; then closes all controllers including the three new ones. Controllers are not closed in `disconnect()`, preserving the broadcast-controllers-stay-open invariant.

## Runtime sanity checks

- **Connect → `start()` fails:** Classifiers still null → catch block runs no-op disposes → device disposed → `_device` and classifier fields nulled → rethrow. Next `connect()` enters the `_device != null` guard cleanly. ✅
- **Connect → classifier ctor fails (e.g. `EmotionsClassifier`):** `_nfbClassifier` + `_cardioClassifier` non-null; catch block disposes them, no-ops the third, then disposes the device. ✅
- **Disconnect → reconnect:** All five new subs cancelled, classifiers disposed; controllers stay open; downstream subscribers continue to receive events from the freshly-instantiated classifiers. ✅
- **`dispose()` after a connection cycle:** Subscriptions cancelled, classifiers disposed, device disposed, all controllers closed. ✅
- **`dispose()` with no prior connection:** Null-safe operators throughout; controllers close cleanly. ✅
- **Cardio `heartRate` while metrics unavailable:** `0.0` forwarded unmodified; downstream gating in `BciDataService` is the intended boundary. ✅
- **`stateStream` / `errorStream` subscription before native create completes:** Safe per neiry_kit contract; if `_createError` eventually surfaces, the dedicated `errorStream` will not emit (no events) — the `onError` on the listener catches any platform-channel errors that do occur.

## Summary

All findings from review-1 and review-2 are resolved. No new issues observed.

REVIEW_PASS
