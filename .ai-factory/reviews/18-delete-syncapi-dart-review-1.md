## Code Review Summary

**Files Reviewed:** 3 (+ plan file)
**Risk Level:** 🟢 Low

**Commit:** `ae69379` — "Delete SyncApi.dart"

### Context Gates

- **ARCHITECTURE.md:** No boundary or dependency issues — changes are limited to removing dead JSON deserialization code from model classes. No architectural layers affected. `WARN`: none.
- **RULES.md:** No violations — removed code was in model classes (not services, not App.dart, not DI). `WARN`: none.
- **ROADMAP.md:** Milestone 2.8 correctly marked complete. All sub-items under 2.8 are now `[x]`. `WARN`: none.

### Verification

| Claim | Result |
|-------|--------|
| `SyncResponse.fromJson` has zero callers | Confirmed — grep across `lib/` and `test/`: no matches |
| `BatchSessionsResponse.fromJson` has zero callers | Confirmed — grep across `lib/` and `test/`: no matches |
| `ChangeEvent.fromJson` still has callers (preserved) | **Stale** — see suggestion below |
| `SyncGrpcApi` constructs objects directly | Confirmed — `_mapEvent()` and named constructors used at lines 26-31, 38, 42-47 |
| `SyncGrpcListener` constructs objects directly | Confirmed — `_mapEvent()` at lines 78-84 |
| Remaining imports still valid | Confirmed — `SyncResponse.dart` still imports `ChangeEvent.dart` (for `List<ChangeEvent>` field); `BatchSessionsResponse.dart` still imports `BreathSession.dart` (for `List<BreathSession>` field) |

### Critical Issues

None.

### Suggestions

- **`ChangeEvent.fromJson` is now dead code.** The plan preserved it because `SyncSocketListener` was its only caller. However, `SyncSocketListener` was already deleted in milestone 3.6 (commit `32bc6a4`), so `ChangeEvent.fromJson` now has zero callers anywhere in `lib/` or `test/`. It could be removed for consistency with the other two `fromJson` deletions in this commit.

### Positive Notes

- Minimal, surgical changes — only dead code removed, nothing else touched.
- Roadmap update is correct and complete.
- The plan's analysis of which `fromJson` factories were dead was accurate for `SyncResponse` and `BatchSessionsResponse`.
