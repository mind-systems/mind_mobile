# Plan Review: Fix PPG not activating + Android disconnect crashes in `NeiryBciProvider`

**Plan:** `100-fix-ppg-not-activating-android-disconnect-crashes-in-neirybciprovider.md`
**Files Reviewed:** 1 plan + target (`lib/Bci/NeiryBciProvider.dart`) + `neiry_kit` Device/CardioClassifier API
**Risk Level:** 🟢 Low

## Verification Against the Codebase

Every concrete claim in the plan was checked against source. All hold:

- **API exists.** `Device.unregisterCallbacks()` (device.dart:186) and `Device.stopStream()` (device.dart:228) are both public, both `Future<void>`. The SDK doc-comments confirm the exact invariants the plan relies on: `unregisterCallbacks` "Must be called before cancelling fan-in subscriptions … and before disposing classifiers"; `stopStream` is meant "inside a disconnect sequence so that classifiers can still be disposed … before disconnect releases [the handle]."
- **Task 1 is sound.** `CardioClassifier(device)` requires `device.isConnected` (cardio_classifier.dart:72-77), and `_connected` is set synchronously the instant `await connect()` returns (device.dart:176). So constructing the four classifiers immediately after `connect()` and before `start()` is valid — the `isConnected` guard passes, and the constructor's native `create` call (which fires the PPG mode switch) now precedes streaming. The `start()` precondition (`_checkConnected`, device.dart:215) is likewise satisfied.
- **Line references are accurate.** `connect()` try/catch at 155-185, `_teardownAfterUnexpectedDrop()` microtask at 464-502, `disconnect()` at 553-566, comment "All four classifiers are guaranteed non-null here" at 205 — all match.
- **catch-cleanup claim holds.** The `connect()` catch block (162-185) disposes each classifier defensively with `?.` + `try/catch`, so reordering the creation cannot break it.
- **Boundary respected.** Changes are confined to `NeiryBciProvider`, the sole permitted `neiry_kit` importer. No proto, no module-Service, no `App.dart` involvement.
- **Ordering in Task 3 is correct.** unregisterCallbacks → cancel subs → dispose classifiers → stopStream → disconnect → dispose, every new call wrapped in `try/catch`. The captured `device` local is in scope. Matches SDK invariants.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** No boundary violation — the adapter-only `neiry_kit` import rule is preserved. **OK.**
- **Rules (`RULES.md`):** The three rules concern module Services / `App.dart` / constructor injection — none apply to this provider. **OK.**
- **Roadmap (`ROADMAP.md`):** Present; this is a `fix`. The plan does not reference a milestone. `WARN` (non-blocking) — consider linking the milestone for traceability.
- **Skill-context (`aif-review/SKILL.md`):** Not present. **OK.**

## Recommendations (non-blocking)

1. **`disconnect()` — `unregisterCallbacks()` is unguarded.** Task 2 (and the spec note's example) place `await _device?.unregisterCallbacks();` as the first statement, *outside* the existing `try/catch`. `unregisterCallbacks()` calls `_checkNotDisposed()` (device.dart:187), which throws `StateError` if the device is already disposed. On that edge case the throw propagates before `_device = null` and before the explicit `disconnected` emit run — leaving the provider in a half-torn-down state where a subsequent reconnect's `connect()` would hit its `StateError` guard. Given the whole point of this change is crash-hardening, recommend guarding it (e.g. its own `try { await _device?.unregisterCallbacks(); } catch (e) { logPrint(...); }`) so cleanup always completes. The happy path (device connected, not disposed) is unaffected, so this is a robustness improvement rather than a correctness blocker.

2. **Path label.** The plan Notes and spec note cite `neiry_kit/lib/src/api/device.dart` as if it sits under `mind_mobile/`. It is actually a sibling repo wired via `pubspec.yaml` path `../neiry_kit`. The file exists and the implementer will find it; just a cosmetic inaccuracy.

3. **Task dependencies.** Tasks 2 and 3 are tagged "(depends on Task 1)" but touch different methods and are functionally independent of the connect-ordering change. Harmless; the conservative dependency only forces sequencing.

## Positive Notes

- The plan is unusually precise: exact insertion points, explicit "do not touch" boundaries (`_doDispose()`, `_cancelDeviceSubscriptions()`, the connect catch block), and correct rationale tied to verifiable SDK doc-comments.
- Logging discipline matches the "minimal" setting — silent `catch (_) {}` on the best-effort unexpected-drop path, existing logged catch reused on the explicit disconnect path.
- Scope is correctly limited to one file with no proto/DI/schema ripple.

The plan is accurate, implementable, and architecturally clean. The one robustness note above is worth applying during implementation but does not block.

PLAN_REVIEW_PASS
