# Time-of-Day Suggestions Widget

## Layout

A thin-bordered card widget on HomeScreen — positioned **above all other content** (module grid, StatsCard). It is a `SliverToBoxAdapter` inside the existing `CustomScrollView`, so it scrolls together with the rest of the screen.

```
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  Для утренней бодрости
│ ┌──────────┐ ┌──────────┐          │
  │ Утреннее │ │ Глубокое │  ···
│ │ дыхание  │ │ расслаб- │          │
  │          │ │ ление    │
└ └──────────┘ └──────────┘ ─ ─ ─ ─ ┘
```

- Thin border around the whole widget
- Title at the top — localized, chosen randomly per time slot (see below)
- Horizontal scroll of session cards inside
- Card width: slightly less than half the screen width
- Card height: fits 2 lines of session name (fixed height)
- Cards are tappable — open the session

---

## Auto-scroll Behavior

- On appear: cards slowly auto-scroll in one direction (like a conveyor belt)
- When reaching the end: reverse direction, scroll back
- When the user manually scrolls: auto-scroll stops permanently for that session
- Speed: slow, ambient — should feel calm, not distracting

---

## Localized Titles

Titles are localized (ARB files) and picked randomly within the current time slot.

**Morning** (5:00–11:59):
- "Good morning"
- "Morning energy"
- "Start your day right"
- "Wake up gently"

**Midday** (12:00–16:59):
- "Midday reset"
- "Recharge your focus"
- "Take a breath"
- "A moment for yourself"

**Evening** (17:00–4:59):
- "Wind down"
- "Evening calm"
- "Prepare for rest"
- "End the day well"

Night (0:00–4:59) maps to **morning** slot.

---

## Implementation Notes

- Follow existing style: spacing, border radius, colors from theme tokens (`mind_ui`)
- Auto-scroll implemented as a pure UI concern inside the widget — no ViewModel involvement
- Random title selected once on widget build, not on every rebuild
- Localization keys added to all ARB files (`mind_l10n` package)
