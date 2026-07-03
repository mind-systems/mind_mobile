# Code Review — Update realtime docs to the root/child model (review 2)

**Scope:** documentation-only milestone. Changed source files: `docs/realtime/data-flow.mmd`, `docs/realtime/live-session-tracking.md`, `docs/realtime/meditation-tracking.md`. "Correctness" = the prose accurately describes the shipped, committed root/child behaviour and is internally consistent.

**Method:** re-read all three docs and the full `git diff HEAD`; cross-checked behavioural claims against shipped code (`MeditationModuleStateChannel.dart`, `KeepAliveCoordinator.dart`, `RootStateChannel`/`ModuleStateChannel`/`BiometricStreamClient`) and governing notes 14–20, 25, 26.

## Round-1 finding — resolved

Review 1's blocking finding (meditation `## Реализация` re-introducing the retired stop-on-dispose behaviour and contradicting line 11) is fixed. The section now ends:

> Уход с экрана без нажатия Stop команду завершения не отправляет — сессия остаётся живой дочерней сессией на root'е, как описано выше.

This matches the shipped `MeditationModuleStateChannel` (`dispose()` cancels subscriptions only; `end` fires solely on the `active → idle` Stop transition) and is now consistent with the lifecycle intro. Confirmed by grep: no `останавливается при закрытии` / `channel.stop` / `dispose()` residue remains in any realtime `.md`.

## Verification this round

- **No stale-model phrases** in `docs/realtime/*.md` / `*.mmd` — grep for "корреляционный ключ", "одну активную сессию", server-side pause filter ("блокирует входящие") returns nothing. Residual matches exist only in the CI-regenerated `data-flow.svg`, correctly left un-hand-edited per the plan.
- **`data-flow.mmd`** — "one active session per user" → "root + N concurrent children"; single "correlation key" edges → bio→`root.id` / phase→child-id split time-joined against the root timeline. Consistent with the prose; no new node ids, so `.mmd` reserved-word pitfalls do not apply.
- **`live-session-tracking.md`** — root + N flat concurrent children; root opened on connect and never client-ended; bio bound to `root.id`, phases to the child id; client-owned pause gap (server filters nothing); reconnect via `root.id` header + reconcile-by-arrival with trusted `is_paused`; whole-tree synchronized grace/abandon; last-connect-wins passive/"use here" resilience. All match notes 14–20. Behaviour-level throughout — no FSM / `SessionTerminated` / enum internals leaked. FGS section correctly re-described via the two independent signals (server child lifecycle + local live edge, latter covering the offline path), matching `KeepAliveCoordinator`.
- **`meditation-tracking.md`** — meditation framed as one child among N on the shared root; ends only on explicit Stop; screen exit keeps the child live with bio recording; the "Чего нет" table and `## Реализация` block reworded to behaviour-level with the retired lifecycle language removed.

No bugs, security issues, or correctness problems found. This is a docs-only change with no runtime surface (no migrations, types, or concurrency to break).

REVIEW_PASS
