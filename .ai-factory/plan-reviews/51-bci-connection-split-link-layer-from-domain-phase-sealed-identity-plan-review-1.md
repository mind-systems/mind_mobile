# Plan Review: BCI connection — split link-layer from domain phase + sealed identity

## Code Review Summary

**Plan reviewed:** `51-bci-connection-split-link-layer-from-domain-phase-sealed-identity.md`
**Files in scope:** 6 (`BciLinkStatus.dart` new, `BciConnectionState.dart`, `IBciDeviceProvider.dart`, `NeiryBciProvider.dart`, `BciDeviceManager.dart`, `BciPairingService.dart`, `BciDataService.dart`)
**Risk Level:** 🟢 Low

The plan is well-scoped, the line references are accurate, and the migration surface is genuinely contained. I verified independently:

- `NeiryBciProvider` is the **only** implementer of `IBciDeviceProvider.connectionStateStream` (`:71`); no fakes/mocks exist, so retyping the interface stream breaks nothing outside the plan's file list.
- `BciDeviceManager._connectionStateSub` (`:61`) is the **only** subscriber to that stream — and it already reacts solely to `disconnected`, never to the old `connected→connecting` mapping. Dropping link-layer `up` handling in the manager is therefore safe.
- A full grep for `BciConnectionState` across `lib/`, `packages/`, and `test/` returns only the 6 plan-targeted files plus `BciNotifierEvent.dart` (which holds the type as a field and needs no change since the sealed base keeps the same name). No widget, ViewModel, package, or test references the enum members directly — they all consume DTOs. The atomic single-commit rationale is correct.
- The sealed design is valid Dart: both `BciConnectionState` and `BciActive` are `sealed` in one library, so exhaustive `switch` over the 7 leaves compiles without `default`. `const BciConnecting(super.serial)` super-parameter form is valid.
- ROADMAP linkage exists (Phase 39 — "BCI connection domain model").

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN (non-blocking). The change respects the layering — domain types stay in `lib/Bci/Models/`, neiry_kit stays behind `NeiryBciProvider`, DTOs unchanged at the module boundary. No boundary violation.
- **Rules (`.ai-factory/RULES.md`):** No applicable rule violations found (no sealed/switch/enum conventions defined). Logging stays minimal per plan Settings.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS. Phase 39 entry matches the plan's intent and spec note `103`.
- **Docs:** WARN (non-blocking). `docs/bci/device-manager.md` describes the connection state machine and will drift. Plan Settings say Docs: no, so this is accepted — flagging only so it is a conscious choice.

### Critical Issues

None blocking.

### Issues to Address

**1. Task 5 — the unexpected-disconnect reconnect trigger silently widens to include `BciConnecting`.**

The current guard (`BciDeviceManager.dart:62-66`) fires the unexpected-disconnect / auto-reconnect path only when `_state ∈ {impedance, calibrating, ready}` — it **explicitly excludes `connecting`**:

```dart
if (state == BciConnectionState.disconnected &&
    _state != BciConnectionState.disconnected &&
    _state != BciConnectionState.scanning &&
    _state != BciConnectionState.connecting &&            // <-- connecting excluded
    _state != BciConnectionState.bluetoothPermissionDenied) {
```

The plan rewrites this as "fire reconnect only when `_state is BciActive` (i.e. not Idle/Scanning/PermissionDenied)" (Task 5, bullet 2). But `BciActive` **includes `BciConnecting`** — so the plan's `is BciActive` check re-admits the `connecting` state that the original deliberately excluded. This is a semantic change the plan does not acknowledge.

In practice this is **benign** (not a runtime bug): during `connectDevice`'s `await _provider.connect(serial)`, the provider has not yet established its device-level `_connectionSub` (it subscribes only after `_device!.start()` succeeds), so no link-layer `down` can be emitted while `_state is BciConnecting`; and the explicit-disconnect emit (`:592`) only runs under `disconnect()` which sets `_suppressAutoReconnect = true`. So no `down` interleaves the connecting window today.

**Recommendation:** either (a) preserve the original exclusion explicitly — gate on `_state is BciActive && _state is! BciConnecting` (or equivalently `is BciImpedance || is BciCalibrating || is BciReady`) to keep behavior identical, or (b) keep `is BciActive` but add one line to the plan noting the connecting-state inclusion is intentional and safe for the reasons above. Right now the plan changes behavior implicitly, which is the kind of thing that silently regresses later. Prefer (a).

**2. Task 5 — make the `_setState` dedup helper explicit about `BciActive` subtype matching.**

The plan correctly identifies that `next == _state` no longer dedups (instances aren't value-equal) and proposes "compare `runtimeType` and (for `BciActive`) `serial`." That is right, but worth stating the exact predicate in the plan so the implementer doesn't accidentally compare `is BciActive` (which would treat `BciImpedance(x)` and `BciReady(x)` as equal and swallow the impedance→ready transition). The intended form is:

```dart
bool _isSameState(BciConnectionState a, BciConnectionState b) {
  if (a.runtimeType != b.runtimeType) return false;       // distinguishes Impedance vs Calibrating vs Ready
  if (a is BciActive && b is BciActive) return a.serial == b.serial;
  return true;
}
```

`runtimeType` inequality must short-circuit first; only same-runtimeType `BciActive` pairs compare `serial`. The plan's wording ("compare runtimeType and (for BciActive) serial") implies this but is loose enough to misimplement. Spell it out.

### Minor Notes

- **Task 6 improvement is correct and worth calling out:** the new reducer sets `connectedSerial: state.serial` in *every* `BciActive` arm, whereas the original `calibrating`/`ready` arms omitted `connectedSerial` and relied on it persisting from the `impedance` arm. Since the serial is invariant across `connecting→impedance→calibrating→ready`, the new behavior is strictly more correct. No action needed — just confirming it is intended.
- **Task 6 — `impedance` arm fallback drops away cleanly.** The original `connectedSerial: _connectingSerial ?? acc.connectedSerial` becomes `state.serial`. Since `BciImpedance` always carries a serial, the `?? acc.connectedSerial` fallback is no longer reachable and correctly removed. Good.
- **`startScan` direct-write bypass is still required** under the new dedup (a fresh `BciScanning()` would be deduped against an existing `BciScanning` by the runtimeType comparison), and the plan preserves it. Correct.
- **`_attemptReconnect` `_setState(BciScanning())`** fires correctly because the `down` handler sets `BciIdle()` first (Idle→Scanning differ by runtimeType). The existing dedup-safety comment in `_attemptReconnect` (`:256-261`) should be updated to reference the new `is`-based states rather than the enum members, or it becomes misleading. Minor.

### Positive Notes

- The link-layer / domain split is the right model: `BciLinkStatus` for the provider stream and a `BciActive(serial)`-rooted sealed hierarchy for the domain phase makes "connecting without serial" and "disconnected with serial" unrepresentable, which is exactly what kills the `_connectingSerial` + `devices.length == 1` heuristic bug.
- Single-commit rationale is sound — the type rewrite breaks every consumer simultaneously, so no intermediate commit could compile.
- Line references in every task were verified accurate against the current source.
- `_connectedSerial` reconnect-memory is correctly preserved (Task 5, spec Guards) — deleting it would break auto-reconnect.
- Exhaustive-switch / no-`default` discipline is called out per file, which lets the compiler flag any missed migration site.

### Verdict

The plan is implementable and low-risk. Address Issue 1 (preserve or consciously document the `connecting`-state exclusion in the reconnect trigger) and tighten the Issue 2 dedup predicate wording before implementation; neither requires re-architecting the plan.
