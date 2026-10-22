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
  keeps its own state for the rest of the loop while you are elsewhere (`_saved`). It reads the
  day and flags from `Run.life` ([loop.md](loop.md)).
- **It never plays a scene itself:** it asks the game through `requests` (`talk`, `use`,
  `arrive`, `scene`, `cast`, `exit`, `period`); [story.md](story.md) answers.
- `reach` 30 px to talk or use; Vitality regenerates out of fights (`spells.json`
  `wizard.regen_out`, 2% a second), up to the Injured cap ([loop.md](loop.md)).
- **The clock** only runs on walking when `world.json` `walk_clock` is true; it is false since
  N-1.1, so only actions pass time ([loop.md](loop.md)).

## Regions and travel (`data/world/regions.json`, `scripts/game/reach.gd`)

*Target: Ring 1 as places to walk and fight in (the camp re-dressed, the fallen city and its
undercroft beside the halls, the Mill fields and the east road; place ids, landmarks, grade gates
and their second routes, puzzle sites, every fight's room and terrain hooks, where Lantern Night
hits, and where shops, crews, powers and the two roads sit) is the
[Ring 1 places and fights spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
(tracker M0-16; visual: [Ring 1 Atlas](https://claude.ai/artifact/WdcauyacBwZJN3vgvRkius)). What
follows is the build today.*

- **Regions** group maps: the survivors' camp (`camp`) and the fallen city of Vellmar (`city`,
  whose one map so far is the College halls, arriving at `landing`). Each has a name, ring, a
  place on the chart (`pos`), its `maps` (the first is where travel arrives), `arrive` (the spot)
  and a `blurb`. A region with no maps is a **card**: the Mill fields and east road (Ring 1) and
  four Ring 2 regions show their blurb and cost no time (the Wuxia rule).
- **Roads** `[a, b, days]`; a journey takes the cheapest roads' days (`days_between`). Walking
  inside a region is free.
- **The Reach** is the map's second tab (M, then 2): the chart, roads with their days, and a card
  for the region picked. "Go to …" (from anywhere, with nothing hunting you) passes the days and
  you arrive at the region's spot that morning, behind the loading card, not rested. If the
  Eclipse falls on the road, it comes first.
- The camp's north stair still leads straight down to the halls for free (the build's shortcut).

## People (`scripts/world/people.gd`, `data/world/people.json`)

*Target: how people and powers judge what you do (standing, fame and infamy, the numbered blame
ladder, suspicion, amends, bounties) is the [powers and reputation spec](/mnt/project-files/design/powers/powers-and-reputation-spec.md)
§9 (tracker M0-14). What follows is the build today.
*Target for the people themselves (schedules by season, weather and events; how they react; friendship
tiers, gifts and tastes, companions, sworn friends; what of them carries across lives): the
[people and side activities spec](/mnt/project-files/design/people/people-and-side-activities-spec.md)
§3–5 (tracker M0-17; visual: [Folk and Pastimes Atlas](https://claude.ai/artifact/H9gh2FHhiCZ6Sm8iu7zkvS)).*

- Camp only (nobody follows you into the ruin). Each person has a `schedule` of spots per time
  of day, `overrides` (days, times, `when`, `spot`, `seek` to walk up and talk once a loop),
  `from_day`, and `barks` heard within 170 px every 7–15 s.
- They flinch and complain when you cast near them; the captain scolds fire in the College ruins;
  Mira walks the lane at dusk lighting lamps.

## Magic meets the world (`data/world/props.json`)

*Target design: [spells and the environment](/mnt/project-files/design/world/spells-and-environment-spec.md)
(2026-10-22, tracker M0-6; visual: [World Matter Atlas](https://claude.ai/artifact/2kDFnWVKykbTzChnjmPNhD)):
one force × material table for props, tiles and units, states, fire/water/charge spreading on a cell
grid, breaking and collapse, damage that lasts the life, owners and witnesses. Weather and the seasons acting on matter are in the
[seasons, weather and calamities spec](/mnt/project-files/design/seasons/seasons-and-calamities-spec.md) (M0-13). The gaps are in
[drift.md](drift.md). What follows is the build today.*

- **Fire** spells (`fire_spells`) light lamps and braziers and set hay, crates and carts burning
  (`burns` s, `spread` px, `dps` to enemies standing in it, then ash). **Water** spells put them
  out. **Force** spells shove crates and barrels (`mass`, `roll`, `shove`).
- **Lightning** (`storm_zaps`) flares iron lamps for 1.5 s and charges puddles for 4 s; a charged
  puddle shocks enemies in it (5 every 0.5 s).
- **Rewind** mends burnt and shoved props within 34 px back to how they were.
- **Cantrips** ([combat.md](combat.md)): Kindle acts on the world like Pillar's fire (lights lamps
  and braziers, sets props burning) and Douse like a splash all round its point (puts out props,
  lamps, braziers and burning patches). The **staff strike** shoves the prop in front of it.
- A lit or flaring lamp's pool (`light_r` 38) keeps `light_shy` kinds out.

## Economy, gear and repair (not built)

*Target design: [economy, gear, crafting and repair](/mnt/project-files/design/economy/economy-and-repair-spec.md)
(2026-10-22, tracker M0-15; visual: [Crowns and Crews](https://claude.ai/artifact/NabgfdAiiuJw8ghJPuBkzL)):
one coin (crowns), shops with weekly stock and one price formula (ring, season, scarcity, standing,
infamy), gear slots with fixed tiers and traits, reagents, salvage and benches, Spark Artifice device
charges, commissions, homes and loans, and repair crews who rebuild owned props on the environment
spec's timers using each town's stock. Money, gear and the home reset each life. None of it is built
yet; the gaps are in [drift.md](drift.md).*

## Tests

`tools/tests/world_magic.gd` (each reaction, with real casts), `tools/tests/unit.gd` (maps load,
exits lead somewhere real, pits, reachability, per-map lamps), `tools/map_preview.gd` (top-down
PNG/SVG of every map; CI artifact `map-preview`).
