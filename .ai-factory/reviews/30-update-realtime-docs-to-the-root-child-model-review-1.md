# Code Review — Update realtime docs to the root/child model (review 1)

**Scope:** documentation-only milestone. Changed files: `docs/realtime/data-flow.mmd`, `docs/realtime/live-session-tracking.md`, `docs/realtime/meditation-tracking.md` (plus planning artifacts). "Correctness" here = the prose accurately describes the shipped, committed root/child behaviour and is internally consistent.

**Verification method:** read all three docs in full; cross-checked each behavioural claim against the shipped code (`MeditationModuleStateChannel.dart`, `KeepAliveCoordinator.dart`, `RootStateChannel`/`ModuleStateChannel`/`BiometricStreamClient` per plan-review-1) and against governing notes 14–20, 25, 26.

## Findings

### 1. BLOCKING — meditation doc re-introduces the retired stop-on-dispose behaviour and contradicts itself

`docs/realtime/meditation-tracking.md:54` (the rewritten `## Реализация` section) ends with:

> Если сессия была начата, но явно не завершена (например, пользователь ушёл с экрана до нажатия Stop), она останавливается при закрытии экрана.

This is factually wrong on the shipped code and directly contradicts the same document.

- **Contradicts the code.** The whole milestone (governing spec note 18, shipped) inverts the lifecycle: a child ends **only on explicit finish**, never on screen teardown. The shipped `MeditationModuleStateChannel.dispose()` only cancels its three stream subscriptions — it contains no `_channel.stop()`/`end` call. `end` is sent exclusively on the `active → idle` (Stop) transition in `_onState`. So "она останавливается при закрытии экрана" describes a code path that was removed and no longer exists.
- **Contradicts this doc.** Line 11 of the same file states the opposite and correct behaviour: «уход с экрана медитации сессию не завершает, она остаётся живой дочерней сессией на root'е, и её биометрия продолжает записываться». Line 54 says leaving the screen stops the session; line 11 says it does not. A reader gets both claims in one doc.
- **It is exactly the myth this milestone exists to kill.** Note 18 and the plan's Task 3 explicitly require removing end-on-dispose "everywhere" with "no `dispose()`/flag/method-call residue anywhere". The `## Реализация` block was reworded into prose but the stop-on-dispose sentence was carried through verbatim in meaning, so the central falsehood survived the rewrite.

**Fix:** delete that final sentence (and any implication that closing the screen stops the session). The `## Реализация` section should end with the explicit-finish semantics already stated at line 11 — starting a session emits start; only Stop emits end; navigating away leaves the child live under the root with bio still recording.

## Checks that passed

- **No stale phrases remain in the source docs.** `grep` over `docs/realtime/*.md` / `*.mmd` finds no "корреляционный ключ", "одну активную сессию", or "блокирует" (server-side pause filter). The only residual hits are inside `data-flow.svg`, which is CI-regenerated from the updated `.mmd` and is correctly left un-hand-edited per the plan.
- **`data-flow.mmd`** — "one active session per user" replaced with "root + N concurrent children"; the single "correlation key" edges replaced with the bio→`root.id` / phase→child-id split time-joined against the root timeline. Consistent with the prose. No new node ids introduced, so the `.mmd` reserved-word pitfalls do not apply.
- **`live-session-tracking.md`** — session model (root + N flat concurrent children), root opened on connect and never ended by the client, bio bound to `root.id` and phases to the child id, client-owned pause gap (server filters nothing), reconnect via `root.id` header + reconcile-by-arrival, whole-tree grace/abandon, and the last-connect-wins passive/"use here" resilience behaviour all match notes 14–20. Behaviour-level throughout — no FSM/`SessionTerminated`/enum internals leaked.
- **FGS section** (`live-session-tracking.md:94`) — correctly re-described behaviour-level as driven by two independent signals (server child lifecycle + local "breath activity is live" edge, the latter covering the offline path) and released when both are quiet. Matches `KeepAliveCoordinator` (`onLocalLifecycle` + `_onEvent` start/stop). Raw `ModuleSession*` enum names dropped as required.

Fix finding 1 and the milestone is otherwise accurate and complete.
