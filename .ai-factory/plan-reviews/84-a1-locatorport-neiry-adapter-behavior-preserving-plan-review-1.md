# Plan Review: A1 · LocatorPort + neiry adapter (behavior-preserving)

**Plan:** `.ai-factory/plans/84-a1-locatorport-neiry-adapter-behavior-preserving.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid. One medium-importance ambiguity to make explicit, plus minor nits.

## Verification performed

I cross-checked every codebase assertion in the plan against the actual source:

| Plan claim | Verified |
|---|---|
| `_locator` field at `NeiryBciProvider.dart:35` is `neiry.DeviceLocator _locator = neiry.DeviceLocator();` | ✅ exact |
| `_device?` at `:36`, `_teardownComplete` at `:38` | ✅ |
| Teardown drains at `:106` / `:151` / `:617` | ✅ |
| Inline `.map(...)` scan mapping at `:141-144` | ✅ |
| `createDevice(serial)` at `:158` | ✅ |
| `_locator.dispose()` at `:463`, recreate at `:468`, `try/finally` at `:561-562` | ✅ |
| `_doDispose` `_locator.dispose()` at `:675` | ✅ |
| Only construction site is `lib/Core/App.dart:193` (`NeiryBciProvider()`) | ✅ — grep found no other instantiation in `lib/` or `test/` |
| `BciDeviceInfo` has `serial` + `name` (no `type`) | ✅ |
| `test/Bci/` directory exists | ✅ |

neiry_kit API surface confirmed against `neiry_kit/lib/src/api/`:
- `DeviceLocator.requestDevices({NeiryDeviceType type = .any, int searchTime = 5})` → `Stream<List<DeviceInfo>>` ✅
- `DeviceLocator.createDevice(String serial)` → `Future<Device>` ✅
- `DeviceLocator.dispose()` → `Future<void>` ✅
- `Device` exposes `connect()`, `start()`, `stopStream()`, `disconnect()`, `dispose()`, `bool get isStarted`, and `connectionStateStream` / `resistanceStream` / `batteryStream` ✅ — matches note 158's DevicePort surface exactly.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): PASS. The port/adapter seam (`LocatorPort` + `NeiryLocatorAdapter`) sits inside the `lib/Bci/` domain layer and preserves the existing rule that `NeiryBciProvider` is the only neiry importer — Task 4 explicitly keeps the adapter as the sole new neiry importer. No layer-boundary violation.
- **Rules**: No `.ai-factory/RULES.md` and no `aif-review` skill-context file present (WARN: optional files absent — nothing to enforce). Logging guidance from `CLAUDE.md` (`logPrint` only) is respected — the plan adds no new logging.
- **Roadmap** (`.ai-factory/ROADMAP.md`): PASS. Task is Phase 55 layer A / A1, linked at ROADMAP `:292-294` and consistent with notes 155/156/158/159. Co-dependency with A2 is correctly documented.

## Critical Issues

None. Nothing blocks implementation.

## Findings

### 1. DevicePort stream element types — the real unspecified decision (medium)

This is the one place the plan defers a genuinely hard choice, and it deserves to be called out so the implementer doesn't discover it mid-task.

The three device streams the provider subscribes to in `_subscribeDeviceStreams()` (`:195-209`) emit **neiry types**:
- `connectionStateStream` → `Stream<neiry.NeiryConnectionState>` (consumed by `_onNeiryConnectionState(neiry.NeiryConnectionState)`)
- `resistanceStream` → `Stream<neiry.ResistanceData>` (consumed by `_onResistance(neiry.ResistanceData)`)
- `batteryStream` → `Stream<int>` (the only domain-clean one)

Task 1 requires `DevicePort` to have **no neiry imports**, but says to "leave a clear `// A2:` marker so A2 finalizes element types." That punts to A2 a choice with only two outcomes, and they have very different blast radii:

- **(a) `DevicePort` exposes neiry-typed streams** → the port imports neiry, breaking the "no neiry across the seam" purity that is the entire point of the refactor. Almost certainly wrong.
- **(b) `DevicePort` exposes domain-typed streams** → the neiry→domain mapping (`_onNeiryConnectionState`, `_onResistance`) must move out of the provider and into `NeiryDeviceAdapter`. That is a real relocation of behavior, and to honor the "behavior-preserving / byte-identical" guard A2 must reproduce the mapping exactly (including the `_device == null` idempotency guards in `_onNeiryConnectionState`, which depend on provider state and therefore probably *cannot* move — they have to stay in the provider).

Recommendation: A1's `DevicePort` declaration should not leave this fully open. Add a one-line note to Task 1 stating the resolved direction (most likely: `batteryStream` stays `Stream<int>`; `connectionStateStream` / `resistanceStream` keep emitting raw SDK payloads but A2 must decide whether to wrap or expose), and flag that the connection-state idempotency logic stays provider-side. This keeps A1+A2 honestly behavior-preserving rather than discovering a behavioral move during A2. **Not an A1 blocker** — A1 only declares the interface — but the marker should be more prescriptive than "A2 finalizes."

### 2. Relative import path imprecision (low)

Task 3 says "Import `Models/BciDeviceInfo.dart` and `DevicePort.dart`." From the new `lib/Bci/Ports/` directory the path to the model is `../Models/BciDeviceInfo.dart` (or a `package:` import). Trivial; the implementer will resolve it, but the literal string in the plan would not compile as written.

### 3. "Trivial stub `DevicePort`" in the test is not trivial (low)

Task 6 says `createDevice` "may return a trivial stub `DevicePort`." A stub still has to implement all 9 members (5 methods + `isStarted` + 3 streams). That's fine and small, but "trivial" undersells it — the implementer should expect to stub the three streams (e.g. empty/never streams) and `isStarted => false`. No correctness risk.

## Positive Notes

- **Line-accurate.** Every cited line number matches the current file — rare and valuable for a behavior-preserving refactor.
- **Factory-not-instance reasoning is correct and necessary.** The locator is genuinely recreated at `:468`/`:562`, so injecting a single instance would break the reset path. The `LocatorPort Function()` factory is the right call, and the plan justifies it.
- **Singleton interplay handled correctly (worth noting explicitly).** `neiry.DeviceLocator()` is a documented singleton (`device_locator.dart:34-62`): it returns the existing instance until `dispose()`, after which the next call creates a fresh one. The default factory `() => NeiryLocatorAdapter()` wrapping `neiry.DeviceLocator()` therefore reproduces today's exact lifecycle — and the fake deliberately bypasses the singleton, which is precisely the seam's purpose. The plan's byte-identical claim holds.
- **`scan()` mapping relocation is exact.** Moving `list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name))` into the adapter and having the port yield already-mapped `List<BciDeviceInfo>` is byte-identical; the SDK default `type` is `.any` but the provider always passed `headband`, and the `BciScanDeviceType.headband` default preserves that.
- **Teardown gate explicitly fenced off.** The hard guards correctly forbid touching `_teardownComplete`, the drains, the `try/finally`, and ordering — exactly the fragile invariants documented in notes 155/156.
- **Co-dependency with A2 is honestly stated**, including the explicit warning not to expect a green build from A1 in isolation and that verification is joint. This prevents a false "A1 doesn't compile" panic.
- **Anti-goals respected** — no domain latches or `ModuleStateEvent` bus folded in; classifier construction correctly deferred to A3.

## Conclusion

The plan is accurate, well-scoped, and faithful to the characterization-first intent. The only substantive item (finding 1) is a deferred design decision in the co-dependent A2 territory, not an error in A1 — but the `DevicePort` declaration should carry a more prescriptive marker so the byte-identical guarantee isn't quietly compromised when A2 wires the device streams. Findings 2–3 are cosmetic. Safe to implement.
