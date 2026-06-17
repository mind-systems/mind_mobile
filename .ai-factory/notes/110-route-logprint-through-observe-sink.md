# Route logPrint through the observe sink

**Date:** 2026-06-18
**Source:** conversation context

## Key Findings

- `lib/Logger.dart`'s `logPrint(Object?)` is the single most-used logging entry point (57 call sites). This milestone makes it forward each record to the `observe` SDK in addition to / instead of the console, governed by `LOG_DESTINATION`. **Zero call sites change** — `logPrint`'s signature is untouched; only its body changes.
- The forwarding is fire-and-forget: `observeSink(String, {Level})` never throws, batches internally, and tolerates offline. A failed export never affects the UI or the console path.
- Level is intentionally dropped — everything ships as the SDK default `info`. Tags continue to live inside the message string (call sites already prefix with `[Area]`).

## Details

### Current state
```dart
void logPrint(Object? object) {
  final now = DateTime.now();
  final time = '...';            // [HH:mm:ss.SS]
  debugPrint('[$time] $object');
}
```
Console only, no persistence.

### The change
- Keep the existing `debugPrint('[$time] $object')` console output, gated on `logToConsole` (the resolver added in note 109).
- When `logToObserver`, also call `observeSink(object?.toString() ?? '')`. Send the **raw message without the `[$time]` prefix** — Loki carries its own `timeUnixNano` from the SDK, so the prefix would be a redundant second timestamp.
- Import `package:observe/observe.dart` (for `observeSink`).

Resulting shape:
```dart
void logPrint(Object? object) {
  if (logToConsole) debugPrint('[$time] $object');
  if (logToObserver) observeSink(object?.toString() ?? '');
}
```

### Guards
- Never throws (guaranteed by `observeSink`); do not add try/catch around it.
- Console format stays byte-for-byte identical when `logToConsole` is on.
- No `Level` parameter on `logPrint` — all `info`.
- `logToConsole` / `logToObserver` come from the note-109 resolver; do not re-declare them.

### Verify
- With `LOG_DESTINATION=both`, exercise any feature that calls `logPrint`; the lines appear in Grafana via `observe-logs window --project mind --service mind_mobile`, and still print to the console.
- With `LOG_DESTINATION=file`, nothing reaches Loki; console unchanged.

## Open Questions

None.
