# Patch: 50-copy-proto-files-to-mind-mobile

**Source review:** `reviews/50-copy-proto-files-to-mind-mobile-review-1.md`

## Issue 1: Stale `'LiveSession'` log tag in `BreathModuleStateChannel.dart`

**File:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`

**Problem:** Five `dev.log()` calls use `name: 'LiveSession'` as the log tag. The "live" terminology was replaced with "module session" / "module state" across the entire codebase in this rename. The log tag is the only surviving reference to the old naming.

**Impact:** Cosmetic — no runtime or compilation issue. Log filtering by tag would be inconsistent (grepping for `'ModuleState'` or `'BreathModuleState'` would miss these entries).

**Fix:** Replace `name: 'LiveSession'` with `name: 'BreathModuleState'` on all five lines. The tag `'BreathModuleState'` matches the class name pattern used elsewhere (e.g. `name: 'ModuleStateChannel'` in `ModuleStateChannel.dart`, `name: 'ModuleInstructionStream'` in `ModuleInstructionStream.dart`).

### Diff

```dart
// Line 65
- dev.log('BreathModuleStateChannel: session start [$_sessionId]', name: 'LiveSession');
+ dev.log('BreathModuleStateChannel: session start [$_sessionId]', name: 'BreathModuleState');

// Line 69
- dev.log('BreathModuleStateChannel: session resume [$_sessionId]', name: 'LiveSession');
+ dev.log('BreathModuleStateChannel: session resume [$_sessionId]', name: 'BreathModuleState');

// Line 74
- dev.log('BreathModuleStateChannel: session pause [$_sessionId]', name: 'LiveSession');
+ dev.log('BreathModuleStateChannel: session pause [$_sessionId]', name: 'BreathModuleState');

// Line 79
- dev.log('BreathModuleStateChannel: session end [$_sessionId]', name: 'LiveSession');
+ dev.log('BreathModuleStateChannel: session end [$_sessionId]', name: 'BreathModuleState');

// Line 123
- dev.log('BreathModuleStateChannel: dispose — stopping session [$_sessionId]', name: 'LiveSession');
+ dev.log('BreathModuleStateChannel: dispose — stopping session [$_sessionId]', name: 'BreathModuleState');
```
