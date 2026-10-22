# Content: maps, people, story, Ledger text (index)

*A content spec: where content lives and its conventions. `spec_check.py` exempts these paths
(`map.json` `exempt`); a change that needs a new key, effect or rule changes the owning system's
spec instead ([world.md](world.md), [story.md](story.md), [loop.md](loop.md)). Design:
[design/ruins/content.md](/mnt/project-files/design/ruins/content.md) (beats, people, places).*

## Where it lives

| Content | Files | Format owner |
| --- | --- | --- |
| The camp's layout: walls, houses, tents, places, spots, items, lamps, exits, street graph | `data/world/map.json` | [world.md](world.md) |
| A ruin layer's layout: walls, rubble, pillars, pits, cracks, doors, exits | `data/ruins/<layer>/map.json` | [world.md](world.md) |
| A layer's recorded paths (replays, traces) | `data/ruins/<layer>/paths.json` | [story.md](story.md) |
| The camp's people: schedules, overrides, barks, figures | `data/world/people.json` | [world.md](world.md) |
| Scenes | `data/world/story/*.story` (camp), `data/ruins/<layer>/story/*.story` | [story.md](story.md) |
| Ledger entries and death lines | `data/world/ledger.json` | [loop.md](loop.md) |

## Counts (2026-10-22)

- Maps: 2 (camp, halls). People: 6 in the camp (Mira, Aldous, Pell, the watch captain, the
  pie-seller, a stray dog).
- Story: `camp.story` and `halls.story`.

## Conventions

- Display text is English (the game's Western tone; GDD 01). Ids are lower_snake_case.
- A new ruin layer is a folder `data/ruins/<layer>/` (map.json, paths.json, story/) plus a line in
  `data/world/maps.json`; adding the line is a world change (update [world.md](world.md)'s
  'Built' list).
- `tools/tests/story_lint.gd` must pass: every scene's people, items, spots and exits exist on its
  own map.
