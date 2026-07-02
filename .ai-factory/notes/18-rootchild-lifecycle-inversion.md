# Root/child — invert lifecycle: end only on explicit finish (drop stop-on-dispose)

**Date:** 2026-07-02
**Source:** conversation context; handoff §7 (lifecycle inversion); `docs/realtime/meditation-tracking.md:74`

## Key Findings

- Old rule: the client ended the session when leaving the activity screen (adapter `dispose()` sends `stop`). New rule: a child stays live while the user navigates away — end/stop only on **explicit user finish**. This is the whole point of concurrent children (start breathing mid-meditation; meditation keeps running).
- Both module adapters send `stop()` on dispose today — this is the behavior to remove.
- Depends on note 14 (registry) so leftover live children are tracked; independent of bio/reconnect tasks.

## Details

### Current state (exact)
- `lib/BreathModule/Core/BreathModuleStateChannel.dart`: `dispose()` → `_channel.stop()` when a session is started but not ended (`:159-160`). Explicit lifecycle already fires `end` on `→completed` (`:107-112`).
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`: `dispose()` → `_channel.stop()` (`:62`); `end` fires on `active → idle` (Stop tap, `:51-57`).

### Change
- Remove the dispose-time `stop()` in both adapters. End is sent only by the explicit finish transitions already present (breath `→completed`; meditation `active → idle`).
- Audit every navigation path that today tears the session down implicitly (screen pop, coordinator dispose, route change) and confirm none sends end/stop; only the explicit finish action does.
- Reconcile with note 15/19: a child left live on navigation remains in the registry and continues (bio under the root keeps flowing).

### Guards
- Do not remove the explicit-finish `end` paths — only the implicit dispose `stop`.
- Do not touch FGS/biometrics gating here (separate concerns); this task is purely the lifecycle trigger inversion.
- Meditation deliberately keeps recording biometrics in background — leaving the screen must not stop it.

### Verify
- Navigate away from a running breath/meditation screen → no `end`/`stop` sent; the child stays live on the server; bio continues.
- Explicit finish (breath complete / meditation Stop) → `end` sent with the child's `session_id` (note 16).
- Start meditation, navigate to breathing, start it, finish breathing → meditation still live; only breath ended.
