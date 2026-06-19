# Plan Review 2: BCI connection — split link-layer from domain phase + sealed identity

## Code Review Summary

**Plan reviewed:** `51-bci-connection-split-link-layer-from-domain-phase-sealed-identity.md`
**Files in scope:** 6 editable — `BciLinkStatus.dart` (new), `BciConnectionState.dart`, `IBciDeviceProvider.dart`, `NeiryBciProvider.dart`, `BciDeviceManager.dart`, `BciPairingService.dart`, `BciDataService.dart`
**Risk Level:** 🟢 Low

This is the second review pass. The plan text is unchanged since review 1. I re-verified every claim independently against the current source rather than trusting the prior review.

### Independent verification

- **Consumer surface is exactly contained.** A fresh grep for `BciConnectionState` across the repo returns 8 files: the 6 the plan edits, plus `BciNotifier.dart` (the `currentState` getter and import) and `BciNotifierEvent.dart` (the `BciStateChanged.state` field). Both of the latter keep compiling untouched because the rewrite preserves the type name `BciConnectionState` as the sealed base — neither needs an edit, and the plan correctly omits them. No widget, ViewModel, package, or test references the type. `packages/bci_module` consumes only DTOs.
- **`NeiryBciProvider` is the sole implementer** of `IBciDeviceProvider.connectionStateStream` (`:70-72`); `BciDeviceManager._connectionStateSub` (`:60-61`) is the sole subscriber, and it already reacts only to `disconnected`, never to the old `connected→connecting` mapping. Retyping the stream to `BciLinkStatus` is therefore safe end-to-end.
- **Sealed design is valid Dart.** Both `BciConnectionState` and `BciActive` are `sealed` in one library, so an exhaustive `switch` over the 7 leaves compiles with no `default`. The `const BciConnecting(super.serial)` super-parameter form is valid.
- **Atomic single-commit rationale holds.** Deleting the enum is a compile break at every `BciConnectionState.<member>` site, so the compiler itself forces the implementer to touch each one — which also means any line reference the plan happens to omit cannot be silently missed.
- **Line references re-checked** against current source: provider `:43-44/:71-72/:246-263/:592`, manager `:138/:181/:189/:195/:215-216/:234/:238`, pairing `:41-44/:102-184`, data `:67-86` — all accurate.

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN (non-blocking). Layering is respected — domain types stay in `lib/Bci/Models/`, neiry_kit stays behind `NeiryBciProvider`, DTOs at the module boundary are unchanged. No boundary violation.
- **Rules (`.ai-factory/RULES.md`):** No applicable violations. Logging stays minimal per plan Settings; existing `logPrint` usage is preserved.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS. Phase 39 ("BCI connection domain model") and spec note `103` both align with the plan intent.
- **Docs:** WARN (non-blocking). `docs/bci/device-manager.md` documents the connection state machine and will drift. Plan Settings say `Docs: no`, so this is an accepted, conscious choice — flagged only for awareness.

### Critical Issues

None blocking.

### Issues to Address (carried from review 1, still open — both non-blocking)

**1. Task 5 — the unexpected-disconnect reconnect trigger silently includes `BciConnecting`.**

The current guard (`BciDeviceManager.dart:62-66`) fires the reconnect path only when `_state ∈ {impedance, calibrating, ready}`; it explicitly excludes `connecting`. The plan rewrites this as "fire reconnect only when `_state is BciActive`", and `BciActive` *includes* `BciConnecting` — so the rewrite re-admits the connecting state the original deliberately excluded.

I re-traced this and confirm it is **benign in practice, not a runtime bug**:
- The link-`down` source (`_onNeiryConnectionState`) is subscribed only at the end of `NeiryBciProvider.connect()`, after `_device!.start()` succeeds (`:186`). During `await _provider.connect(serial)` while `_state is BciConnecting`, there is no subscription, so no `down` can arrive.
- After `connect()` returns, the manager sets `_connectedSerial` and `_setState(BciImpedance(serial))` synchronously (the `registerDevice` call is fire-and-forget) — no `await` between them. Any `down` queued by the now-live subscription is delivered on a later microtask, by which point `_state is BciImpedance`. So reconnect fires under `BciImpedance`, identical to the original.
- The explicit-disconnect emit (`:592`, now `down`) only runs inside `disconnect()`, which first sets `_suppressAutoReconnect = true` and `_connectedSerial = null`, so the `!_suppressAutoReconnect && _connectedSerial != null` guard blocks reconnect regardless.

So the connecting-window inclusion is currently unreachable. **Recommendation (unchanged from review 1):** prefer gating on `_state is BciActive && _state is! BciConnecting` (or `is BciImpedance || is BciCalibrating || is BciReady`) to keep behavior provably identical and resistant to future provider changes; otherwise add one line to the plan stating the `BciConnecting` inclusion is intentional and safe for the reasons above. As written the plan changes behavior implicitly.

**2. Task 5 — spell out the `_setState` dedup predicate.**

The plan says "compare `runtimeType` and (for `BciActive`) `serial`," which captures the right intent but is loose. The exact predicate must short-circuit on `runtimeType` first, so that `BciImpedance(x)` and `BciReady(x)` are *not* treated as equal (which would swallow the impedance→calibrating→ready transitions):

```dart
bool _isSameState(BciConnectionState a, BciConnectionState b) {
  if (a.runtimeType != b.runtimeType) return false;
  if (a is BciActive && b is BciActive) return a.serial == b.serial;
  return true;
}
```

Worth stating verbatim in the plan so it cannot be misimplemented as `a is BciActive`.

### Minor Notes

- **Line refs for `_attemptReconnect` and `startScan` are representative, not exhaustive.** The plan lists `_attemptReconnect (:238, :264, :267, :272)` but the same method also compares `_state == BciConnectionState.scanning` at `:250` (the discovered-device callback) and `:271` (onDone). Likewise `startScan` compares it at `:170` (auto-connect gate) and `:188` (onDone), which the plan's `:138/:181/:189` list doesn't enumerate. All become `_state is BciScanning`. The compiler-forced migration guarantees these are caught, so this is informational only.
- **`startScan` direct-write bypass is still required** under the new dedup (a fresh `BciScanning()` would be deduped against an existing `BciScanning` by the `runtimeType` comparison). The plan preserves it. Correct. The existing dedup-safety comment in `_attemptReconnect` (`:256-261`) references enum members and will read as stale once migrated — a one-line comment refresh would help, but Settings say minimal logging/no docs, so optional.
- **Task 6 reducer is strictly more correct.** Setting `connectedSerial: state.serial` in every `BciActive` arm (instead of relying on it persisting from the `impedance` arm via `_connectingSerial ?? acc.connectedSerial`) is sound because `serial` is invariant across `connecting→impedance→calibrating→ready`. The `?? acc.connectedSerial` fallback becomes unreachable and is correctly dropped. The `devices.length == 1` heuristic — the actual multi-device auto-connect bug — is deleted, which is the whole point of the change.
- **Task 7 mapping is a faithful 1:1** of the existing 7-arm enum switch (`BciIdle`/`BciPermissionDenied` → full reset; `BciScanning`/`BciConnecting` → `isConnected:false`; `BciImpedance`/`BciCalibrating`/`BciReady` → `isConnected:true`). No behavior change. Good.
- **`.startWith(BciStateChanged(bciNotifier.currentState))`** in both services keeps working — `currentState` now returns a sealed instance, still typed `BciConnectionState`. No edit needed there.

### Positive Notes

- The link-layer / domain split is the correct model. `BciLinkStatus { down, up }` for the provider and a `BciActive(serial)`-rooted sealed hierarchy for the domain phase make "connecting without serial" and "disconnected with serial" unrepresentable — which is exactly what eliminates the `_connectingSerial` side-channel and the `devices.length == 1` heuristic.
- The migration surface is genuinely contained and the atomic single-commit rationale is sound: the type rewrite breaks every consumer at once, so no intermediate commit could compile.
- `_connectedSerial` reconnect-memory is correctly preserved (it is distinct from the emitted state); deleting it would break auto-reconnect.
- Exhaustive-switch / no-`default` discipline is called out per file, turning every missed migration site into a compile error.

### Verdict

The plan is implementable, accurate, and low-risk. The two carried-over items are non-blocking refinements — Issue 1 is provably benign today and Issue 2 is a wording tightening — neither requires re-architecting the plan, and the compiler-forced nature of the migration backstops the omitted line references. Addressing Issue 1 explicitly (option a) is recommended for future-proofing but is not a blocker.

PLAN_REVIEW_PASS
