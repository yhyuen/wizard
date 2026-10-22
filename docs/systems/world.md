# The world: maps, exits, people, props, magic in the world (as built)

*Detail: [design/open-world/interactions.md](/mnt/project-files/design/open-world/interactions.md)
(what magic does to things), [design/ruins/tech-plan.md](/mnt/project-files/design/ruins/tech-plan.md)
§1–2, §4–6 (many maps, the ruin kit, cracks, the Warden, doors). Map layouts are content:
[content.md](content.md). Tracker: W-1, W-2, R-1, R-2.*

## Maps (`data/world/maps.json`, `scripts/world/map.gd`)

- **Every walkable map** is listed in `maps.json` with its `path` (its map.json), `kit` (`town` or
  `ruin`, which builders draw it), `name` (the loading card), `story` folder, `mood`, `palette`,
  `clock` and `paths` (recorded paths for cutscenes). `start` is `camp`.
- Built: **camp** (the survivors' camp, `data/world/map.json`, clock runs) and **halls** (the
  College halls, `data/ruins/halls/map.json`, no clock).
- `map.gd` answers collision for a circle (axis-aligned rects and circles in a 96 px grid), whether
  a shot is blocked, water and bridges, which place a point is in, and paths along the street
  graph. **Pits** stop walkers but not shots. **Doors** open by story (`open <door>`) or by day
  (`open_days`, e.g. the burnt door days 1–9). **Cracks** glow and let embers out
  ([combat.md](combat.md)).
- **Exits** are rects that take you to another map's spot behind a loading card (at least 0.9 s,
  and until the new map's shaders are warm). Stepping into an exit plays its `use:` scene first if
  there is one.

## The world in play (`scripts/world/world.gd`)

- Ticks the clock, people, items, lamps, braziers, props and scorches on the current map. Each map
  keeps its own state for the rest of the loop while you are elsewhere (`_saved`).
- **It never plays a scene itself:** it asks the game through `requests` (`talk`, `use`,
  `arrive`, `scene`, `cast`, `exit`, `period`); [story.md](story.md) answers.
- `reach` 30 px to talk or use; Vitality regenerates at 5% a second out of fights.

## People (`scripts/world/people.gd`, `data/world/people.json`)

- Camp only (nobody follows you into the ruin). Each person has a `schedule` of spots per time
  of day, `overrides` (days, times, `when`, `spot`, `seek` to walk up and talk once a loop),
  `from_day`, and `barks` heard within 170 px every 7–15 s.
- They flinch and complain when you cast near them; the captain scolds fire in the College ruins;
  Mira walks the lane at dusk lighting lamps.

## Magic meets the world (`data/world/props.json`)

*Target design: [spells and the environment](/mnt/project-files/design/world/spells-and-environment-spec.md)
(2026-10-22, tracker M0-6; visual: [World Matter Atlas](https://claude.ai/artifact/2kDFnWVKykbTzChnjmPNhD)):
one force × material table for props, tiles and units, states, fire/water/charge spreading on a cell
grid, breaking and collapse, damage that lasts the life, owners and witnesses. The gaps are in
[drift.md](drift.md). What follows is the build today.*

- **Fire** spells (`fire_spells`) light lamps and braziers and set hay, crates and carts burning
  (`burns` s, `spread` px, `dps` to enemies standing in it, then ash). **Water** spells put them
  out. **Force** spells shove crates and barrels (`mass`, `roll`, `shove`).
- **Lightning** (`storm_zaps`) flares iron lamps for 1.5 s and charges puddles for 4 s; a charged
  puddle shocks enemies in it (5 every 0.5 s).
- **Rewind** mends burnt and shoved props within 34 px back to how they were.
- A lit or flaring lamp's pool (`light_r` 38) keeps `light_shy` kinds out.

## Tests

`tools/tests/world_magic.gd` (each reaction, with real casts), `tools/tests/unit.gd` (maps load,
exits lead somewhere real, pits, reachability, per-map lamps), `tools/map_preview.gd` (top-down
PNG/SVG of every map; CI artifact `map-preview`).
