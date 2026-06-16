## Plan Review Summary

**Plan:** Make `ActiveRrSource` testable: inject clock + Timer factory
**Files Reviewed:** plan + `lib/Biometrics/ActiveRrSource.dart`, `lib/Core/App.dart`, RULES.md, ROADMAP.md, note 90
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture** (`ARCHITECTURE.md` present): No boundary/dependency concerns. The change is internal to the `lib/Biometrics/` layer; Biometric streaming is tracked under commit `1675ada`. No new dependencies cross any module boundary. — PASS
- **Rules** (`RULES.md` present): Plan explicitly aligns with Rule 3 ("All dependencies must be injected via constructor"). Injecting `clock`/`timerFactory` is the correct application of this rule. No violations. — PASS
- **Roadmap** (`ROADMAP.md` present): Plan maps 1:1 to roadmap line 97 ("Make `ActiveRrSource` testable: inject clock + Timer factory"), including the same default values (`DateTime.now`, `Timer.new`) and the same test-plan reference (note 90). Linkage is explicit. — PASS

### Critical Issues
None.

### Verification of plan claims against the codebase
- **File path correct.** `lib/Biometrics/ActiveRrSource.dart` exists and is the only source file.
- **Call site correct.** `lib/Core/App.dart:208` is `final activeRrSource = ActiveRrSource([bciProvider]);` — the only production instantiation (grep confirms no others). Named optional params with defaults keep this compiling unchanged. ✓
- **Time-access sites correct and complete.** The plan enumerates exactly the three live uses:
  - `_onInterval` line 65: `_lastSeenAt[index] = DateTime.now();`
  - `_onSilence` line 92: `final now = DateTime.now();`
  - `_restartWatchdog` line 86: `_watchdog = Timer(effective, _onSilence);`
  No other `DateTime.now()` or `Timer(` references exist in the file. `_watchdog?.cancel()` (lines 82, 122) operates on the `Timer` instance and needs no change — correctly left untouched. ✓
- **Tearoff signatures are valid Dart.** `DateTime.now` has type `DateTime Function()`; `Timer.new` has type `Timer Function(Duration, void Function())` matching the standard `Timer(Duration, void Function())` constructor. Both default-value tearoffs type-check against the declared parameter types. ✓
- **Behavior-preserving claim holds.** With defaults applied, the produced calls (`_clock()`, `_timerFactory(effective, _onSilence)`) are semantically identical to the originals. No logic, ordering, or field changes beyond the two new `final` fields.

### Minor observations (non-blocking)
- **Constructor tearoffs require Dart ≥ 2.15.** `Timer.new` as a tearoff (and the unnamed-constructor tearoff syntax) is only valid on Dart 2.15+. This is effectively guaranteed for any current Flutter toolchain, so no action is needed — noting only for completeness. If the implementer hits a parse error on an old SDK, the fallback is `timerFactory = _defaultTimer` with a top-level/static `Timer _defaultTimer(Duration d, void Function() cb) => Timer(d, cb);`.
- **Note 90 mentions `fakeAsync()` as an alternative.** The referenced test plan (out of scope here) suggests both injectable seams and `fake_async`. The plan correctly scopes the test file out (Settings: Testing: no) and delivers only the seams. No conflict.

### Positive Notes
- Tightly scoped, behavior-preserving refactor with explicit "verify no remaining `DateTime.now()`/`Timer(`" acceptance check baked into Task 2.
- Correct dependency ordering (Task 2 depends on Task 1).
- Backward compatibility of the single call site is explicitly called out and verified.
- Directly traceable to roadmap line 97 and note 90; consistent with the sibling "make X testable" milestones (lines 99, 101, 103) using the same injection pattern.

PLAN_REVIEW_PASS
