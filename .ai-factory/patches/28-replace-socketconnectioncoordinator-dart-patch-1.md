# Patch: 28-replace-socketconnectioncoordinator-dart

## Issue 1: `_mapActivityType` never matches the actual caller value

**File:** `lib/Core/Grpc/LiveSessionGrpcService.dart` (lines 387-391)

**Problem:** `LiveBreathSessionService.startSession()` passes `'breath_session'` as the activity type string. This propagates unchanged through `LiveBreathSessionNotifier.start()` → `emitLive('activity:start', {'activityType': 'breath_session', ...})` → `_mapActivityType('breath_session')`. The current implementation only matches the literal `'breath'`, so `'breath_session'` falls through to `ActivityType.ACTIVITY_TYPE_UNSPECIFIED` (sentinel 0). Every breathing session start command reaches the server with the wrong activity type.

**Current code:**
```dart
ActivityType _mapActivityType(String? type) {
  return type == 'breath'
      ? ActivityType.BREATH
      : ActivityType.ACTIVITY_TYPE_UNSPECIFIED;
}
```

**Fixed code:**
```dart
ActivityType _mapActivityType(String? type) {
  switch (type) {
    case 'breath':
    case 'breath_session':
      return ActivityType.BREATH;
    default:
      return ActivityType.ACTIVITY_TYPE_UNSPECIFIED;
  }
}
```

**Why both strings:** `'breath'` is the canonical enum name in the proto (`ActivityType.BREATH`). `'breath_session'` is what `LiveBreathSessionService` actually sends today. Matching both keeps the mapper resilient — if a future caller uses the shorter canonical name, it still works.
