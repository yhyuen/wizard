# Content: maps, people, story, Ledger text (index)

*A content spec: where content lives and its conventions. `spec_check.py` exempts these paths
(`map.json` `exempt`); a change that needs a new key, effect or rule changes the owning system's
spec instead ([world.md](world.md), [story.md](story.md), [loop.md](loop.md)). Design:
[design/ruins/content.md](/mnt/project-files/design/ruins/content.md) (beats, people, places).
Ring 1's target layout (place ids, map sizes, fights by room) is the
[Ring 1 places and fights spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
and its layout data `ring1-layout.json` beside it (M0-16).*

## Where it lives

| Content | Files | Format owner |
| --- | --- | --- |
| The camp's layout: walls, houses, tents, places, spots, items, lamps, exits, street graph | `data/world/map.json` | [world.md](world.md) |
| A ruin layer's layout: walls, rubble, pillars, pits, cracks, doors, exits | `data/ruins/<layer>/map.json` | [world.md](world.md) |
| The fallen city's layout (burned houses, gates, rails, the lens, places), the undercroft's, the Mill fields' and the east road's | `data/city/map.json`, `data/city/undercroft/map.json`, `data/fields/map.json`, `data/fields/east_road/map.json` (written by generator scripts, checked with `tools/map_preview.gd`) | [world.md](world.md) |
| A layer's recorded paths (replays, traces) | `data/ruins/<layer>/paths.json` | [story.md](story.md) |
| The camp's people: schedules, overrides, barks, figures | `data/world/people.json` | [world.md](world.md) |
| Scenes | `data/world/story/*.story` (camp), `data/city/story/*.story`, `data/city/undercroft/story/*.story`, `data/fields/story/*.story`, `data/fields/east_road/story/*.story`, `data/ruins/<layer>/story/*.story` | [story.md](story.md) |
| Ledger entries and death lines | `data/world/ledger.json` | [loop.md](loop.md) |

## Counts (2026-10-22)

- Maps: 6 (camp, city, halls, undercroft, fields, east road). People: 22 (the Ring 1 roster in
  [world.md](world.md) 'People'; 20 in the camp, 2 at the east road's picket).
- Story: `camp.story`, `apprentice.story`, `people.story`, `city.story`, `halls.story`, `undercroft.story`, `fields.story` and `east_road.story`.

## Conventions

- Display text is English (the game's Western tone; GDD 01). Ids are lower_snake_case.
- A new ruin layer is a folder `data/ruins/<layer>/` (map.json, paths.json, story/) plus a line in
  `data/world/maps.json`; adding the line is a world change (update [world.md](world.md)'s
  'Built' list).
- `tools/tests/story_lint.gd` must pass: every scene's people, items, spots and exits exist on its
  own map.
