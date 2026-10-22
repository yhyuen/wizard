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

- **Regions** group maps: the survivors' camp (`camp`) and the fallen city of Vellmar (`city`:
  the city's streets, the College halls and the undercroft under them, arriving at the `wall_gap`). Each has a name, ring, a
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
  The halls' landing has a second stair up to the city's College steps. Once you've opened the
  undercroft's drain grate, the market cellar is a walk down to the undercroft and up into the
  city's square: camp to city with no day passing (below).

## The camp (`data/world/map.json`)

*N-7.1.1, [Ring 1 places spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
§3, §11.1. Not built: the market cellar grate as a way down (the drain and undercroft are N-7.1.3),
the broken wall's climb-down to the Mill side, the cart at the gate and the Guild's oil shed (Lantern
Night's approaches and preparations, N-7.5), the straw targets moving to the watch post, the
workroom moving to the halls, shops, boards and crews behind the new places (N-7.6).*

- **Places** (the map's `places`; the first that holds a point names it): the built ones (your
  shelter, the Lantern Market, the square, Lamplighter's Lane, the Mill, the College gate, the
  ruined yard, the Observatory, the hill, the north stair, the road) and the re-dress's: the
  **great lamp** (Market centre), the **Guild workshop** (Market, east), the **market cellar**
  grate, the **commissions board** and the **camp shrine** (square), the **Crooked Wick** inn
  (east of the square), the **camp smithy** (south of the square), the **infirmary** and the
  **watch post** (by the College gate), the **Mill lane** (the stream's east bank), the **duel
  ring**, the **broken west wall** and the **College tents** (in the yard), and the **grief fire**
  (a kept fire at the foot of the College hill, by the stream). Each new place has a spot of the
  same name.
- **Buildings you walk into** (`buildings`: a rect with a door gap, the roof and front lift while
  you're inside): the Guild workshop, the inn, the smithy and the infirmary, each with a door node
  on the street graph.
- **The great lamp** stands on a stone platform (a solid circle, r 30 px) at the Market's centre,
  its brass coupling where the four lamp circuits meet.
- **24 lamps on 4 circuits** (`lamps` [x, y, group, circuit]; `rails` [circuit, x1, y1, x2, y2],
  runs from cell centre to cell centre): **A** the Gate row (the Market's north edge), **B** the
  Market ring (round the west and south stalls), **C** the Square run (past the Guild workshop to
  the square), **D** the Lane run (down Lamplighter's Lane: Mira's round, now six lamps). Each rail
  is an iron strip a cell wide in the paving; the cell grid paints its cells **iron**, so they
  conduct. Every rail stops at the platform: the coupling is open, so the four circuits are four
  separate networks. Four street lamps outside the Market stay on no circuit.
- **Lightning on a rail** charges along the iron as far as its Force grade reaches (I 24 px, II 60,
  III 240, IV the whole circuit; the ground rule below), and **every circuit lamp on a charged cell
  flares** (logged `flare`), so a strong enough strike lights a whole run for a moment and none of
  the others.

## The fallen city (`data/city/map.json`, `scripts/world/gates.gd`)

*N-7.1.2, [Ring 1 places spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
§4.1, §8, §9. Not built: the drain stair and the undercroft (N-7.1.3), the city's fights and
night nests (N-7.1.6), the Old Watch's rope lift, ley points at shrines, buying the Wick Lane
house, the bakery cellar's beam, the lens turned by Lamplight or the furnace light, and the
Lamplighter trial at the depot.*

- **The map** (3200 × 2400 px, ruin kit, the clock runs): a burned quarter inside the city wall.
  You arrive at the **wall gap** (south), walk the avenue north to the **Sunken Square** (dry
  fountain, six broken lamps, the city shrine, the broken east edge), and on to the **College
  steps** (an exit down to the halls' landing). West: **Cinder Row**, the **bakery**, the
  **glassworks** (three furnaces, the great lens, three mirrors) and the hidden **glassblower's
  loft**. East: **Wick Lane** (the house for sale, a building you walk into), **Bell Street**, the
  **Old Watch**, the **lamp depot** and the **crater's lip**. North-west: the **Archive gate**
  (sealed: Ring 2). The ruin kit draws `blocks` as burned houses (broken walls round a charred
  floor) and the circles `fountain`, `watchtower` and `furnace`.
- **Gates** (`gates.gd`): a map door can carry `gate` (a prop's tag, the prop's 5th field), and
  stands open while that prop is broken or burned to ash; if its owner mends the prop, the door
  shuts again. Bell Street's **barricade** (wood: Fire II burns it, Impact II smashes it; the
  Watch's, worth 30 cr), the depot's **shutter** (iron: Impact II bends it; the Guild's) and the
  bakery's **heap** over the cellar hatch (stone, Impact II). A gate is drawn as its prop only.
- **The winch**: a door's `winch` [x, y] and `grade`: lightning at that grade or more charging the
  rail cell at the winch opens the door for the life ("The winch catches the charge…"). The
  depot's shutter: grade II, on the depot's rail.
- **The lens** (the map's `lens`): any Impact on a **mirror** prop turns it a quarter round
  instead of moving it. When each mirror has the turn the map names (m1 1, m2 2, m3 3), by day
  (not dusk or night), the sun through the lens burns the fuse: the **loft door** opens for the
  life and you learn `glass_fuse` (a soul memory, Ledger insight). Once you know it, fire within
  reach of the fuse opens the loft at once, in any life.
- **The Old Watch** (`structures.json`, `bridges: true`): one post holds its gallery over the
  square's broken east edge. Fell it and, as well as the collapse, the pits under its rect go for
  the life: you can walk from the square to the tower. A new life puts the pits back
  (`Map.pits_all`) and shuts every door a gate, winch or lens opened.
- **Reveal**: an item with `reveal` (the Archive gate's sooted plaque) plays its `cast: water` or
  `cast: fire` scene when Splash's water or fire reaches it; the plaque then reads, and you learn
  `archive_key`.
- **Owners**: the Watch (wall gap, square, Wick Lane, Bell Street), the Guild (the depot), the
  College (its steps and the Archive gate); everything else is nobody's. Ground: stone, the
  crater's lip earth.

### The undercroft (`data/city/undercroft/map.json`)

*N-7.1.3, spec §4.3. Not built: the channel's fight (F9, N-7.1.6), the floor grate that holds a
body, floating the crate to the grate on a flooded channel, Weighting the grate back down or
freezing its chain to shut the Lantern Night approach (N-7.5).*

- **Four rooms** (1400 × 1000 px, ruin kit, the ruin mood): the **drain stair** (an exit up to the
  Sunken Square's `drain_top`; the square has the stair down), the **long channel** (knee-deep
  water three cells wide, walkable, between two dry ledges), the **sluice room** and the **grate
  hall**.
- **The sluice**: a water rect can name a life flag (its 5th field); while the flag is set the
  water is drained (`Map.set_drained`, checked each frame; the ground cells are rebuilt and the
  water's mesh hides). The sluice wheel's scene sets `channel_dry` (drain) or clears it (fill). A
  new life clears it.
- **Exits `opened_by`** a soul memory work only once you know it (`World.exit_open`): the
  undercroft's `grate_up` to the camp's `cellar_top`, and the camp's `drain_down` from the market
  cellar grate to the undercroft's `grate_under`.
- **Shortcuts** (the map's `shortcuts`, `gates.gd`): the **drain grate** opens for good when its
  counterweight crate (a prop tagged `counterweight`) is shoved into the weight's rect, or
  lightning at grade II charges the chain's rail at its post. You learn `drain_open` (a soul
  memory, Ledger insight), so both exits work in this life and every later one.

## Weather (`data/world/weather.json`, `scripts/world/weather.gd`)

*Target: the [seasons, weather and calamities spec](/mnt/project-files/design/seasons/seasons-and-calamities-spec.md)
§3–§5 (tracker N-4.5). Built: N-4.5.1, the roll, the Almanac and the forecast; the ground reads
rain, wind and fire spread (N-4.2, below). Not yet (N-4.5.2): frost, sight, storm strikes, and
rain or snow on screen.*

- **Nine kinds:** Clear, Overcast, Mist, Rain, Storm, Wind, Heat, Frost, Snow, each with a glyph
  colour, a wind range 0–3 and the world inputs N-4.5.2 will read (`wet`, `dry`, `fire_spread`,
  `freezes`, `snow_cover`, `sight_m`).
- **A day's weather per region** (`on(region, day)`: kind, wind, direction of 8) is drawn from the
  region's climate (`regions`, all Ring 1 on `plateau`) for the moon's season, with a hash of the
  soul's `seed`, the region and the day, so **the year's weather is the same every life**. Heat
  doubles in Embermoon and Wind in Leaf-fall (`double`); never more than three Storm days in a
  row (`max_run`). **Pinned** days win: Lantern Night (camp, city: mist, still), the High Tide
  (storm), the Ashen Purge (heat, a west gale of 3), the Eclipse (snow everywhere).
- **A weather spell** can set a region's weather for the rest of the day (`set_today`; not on a
  pinned day). Nothing casts it yet.
- **The Almanac** (`soul.almanac`, region → day → kind) notes each day you wake, arrive in a
  region, or rest or travel through, and carries across lives. **Aldous** (in the camp, "What's
  the sky doing tomorrow?") tells you tomorrow's weather (story effect `forecast`).
- **Shown:** today's glyph, and tomorrow's once forecast, at the end of the calendar row, and the
  kind's name under it ([frame.md](frame.md)); the map's Calendar tab has a glyph on each day you
  know and today's weather in words.

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

## Magic meets the world (`data/materials.json`, `scripts/world/matter.gd`, `data/world/props.json`)

*Target design: [spells and the environment](/mnt/project-files/design/world/spells-and-environment-spec.md)
(2026-10-22, tracker M0-6; visual: [World Matter Atlas](https://claude.ai/artifact/2kDFnWVKykbTzChnjmPNhD)):
one force × material table for props, tiles and units, states, fire/water/charge spreading on a cell
grid, breaking and collapse, damage that lasts the life, owners and witnesses. Weather and the seasons acting on matter are in the
[seasons, weather and calamities spec](/mnt/project-files/design/seasons/seasons-and-calamities-spec.md) (M0-13). The gaps are in
[drift.md](drift.md). What follows is the build today.*

- **The matter core** (N-4.1, spec §2–§4): `data/materials.json` lists the 16 world materials and
  the three unit ones (break grade, fire grade, fuel, conducts, floats, warded), and the force ×
  material table: per material and force, the op at or above the grade and the weak version
  below it (one grade short of breaking cracks, more only dents). `matter.gd` `result()` answers;
  `world.gd` `apply_force(prop, force, grade, impact, dir, push)` carries it out on a prop. Only
  props use it so far.
- **Carriers** (`materials.json` `carriers`): each spell's mark in the world (projectile, zone or
  effect kind) names its force and spell; the grade is the spell's Force grade (its stage, capped
  by the Ring, [growth.md](growth.md)); cantrips are grade I.
- **Props** (`props.json`) have a `material`, `hp` and their own `break`/`fire` grades: hay is
  cloth; crates, carts and barrels are wood; the cart breaks only at Impact II, and the barrel
  (iron-banded) breaks at II and catches only at Fire II.
- **States on a prop:** heat (smoulder 10 s, burning, ash, chilled or brittle 6 s), moisture (wet
  20 s) and integrity (cracked, broken). Fire below the grade only smoulders it (scorched look);
  fire on a wet prop dries it in a puff of steam; water puts out burning and smouldering and wets
  it (a darker, bluish look). Impact at the grade takes its `impact` off the hp (cracked, then
  broken at 0); one grade short cracks it, and a cracked prop's next such hit breaks it. A broken
  prop is a low heap that no longer blocks and can't be shoved. A burning prop lights props within
  `spread` as a grade I fire, so a barrel beside burning hay only smoulders.
- **Fire** spells light lamps and braziers too (`burns` s, `dps` to enemies in a burning prop).
  **Water** spells put lamps and braziers out. **Pebble**, **Fling** and Undertow's wave shove
  what they hit (`mass`, `roll`, `shove`).
- **Lightning** flares iron lamps for 1.5 s, charges puddles for 4 s (a charged puddle shocks
  enemies in it, 5 every 0.5 s), and acts on the props along its line: hay catches at grade I,
  wood only at II.
- **Rewind** (Time) mends burnt, broken and shoved props within 34 px back to how they were.
- **Cantrips** ([combat.md](combat.md)): Kindle acts on the world like Pillar's fire (lights lamps
  and braziers, sets props burning) and Douse like a splash all round its point (puts out props,
  lamps, braziers and burning patches). The **staff strike** shoves the prop in front of it.
- A lit or flaring lamp's pool (`light_r` 38) keeps `light_shy` kinds out (Hollows, Slingers,
  Backward Slingers, embers, the Choir and the Husk). A **Lantern-eater** (N-6.3) isn't: it walks in
  and **smothers** the lamp (`smother_lamp`: out as if doused, logged `smothered`) until someone
  lights it again.
- **Devices** (N-5.2, [combat.md](combat.md)): a Spark Flask's burst is a `flask` mark that acts
  like Pillar's fire (ground, props, lamps, braziers). A Tar Pot turns the cells under its pool to
  **oil** (`cells.gd` `tar`: catches at Fire I, burns 12 s); fire touching the pool lights it all.
- **Burning enemies** (N-6.2, [combat.md](combat.md)) light the ground cell they stand on as
  they run.
- **The Star Lantern** (N-5.3) is a light: while it hangs, its ring is a pool like a lit lamp's
  (`_light_pools`), so light-shy enemies won't step in.
- **Salvage** (`props.json` `salvage`, `salvage_reach` 80): a prop that breaks within 80 px of you
  leaves reagents you pick up at once (a toast): crate 1 glass, barrel 1 oil, cart 1 copper wire.
  It ignores who owned it (owners and witnesses are N-4.4).

### Supports and collapse (`data/world/structures.json`)

*N-4.3, spec §6.4. Not built: ceilings, bridges and towers in the halls, broken meshes per prop
kind, grade gates in map data, people clearing rubble over days, Time mending a fallen structure.*

- **A structure** stands on **posts**: `structures.json` lists, per map, its rect (what it falls
  on), its deck height and its supports. The camp has one, **the leaning gallery** in the ruined
  yard, on two posts. Each support is a prop of kind `post` (wood, hp 3, breaks at Impact II, so
  one grade I Pebble cracks it and the next breaks it; it burns for 20 s).
- **A post breaks or burns to ash** and the structure groans: a red-orange telegraph on its rect
  that fills, dust falling and the deck shaking, for `telegraph_s` 1.5 s (never less than the
  fair-dodge delay for its size). Then it **comes down**: Impact 3 and 30 damage to everyone under
  it (foes and you), the same Impact on the props there, its other posts break, and its cells
  become **rubble**.
- **Rubble** (a cell state, grey blots on the ground): anyone on it moves 30% slower; it smothers
  a fire on its cell; an Impact shot at grade II or more clears the rubble it lands on.
- A fallen structure stays down for the life (it stands again when you wake). Rewind mends a
  post but not what it held.
- **`bridges`**: a structure that falls across a gap (the city's Old Watch) takes away the pits
  under its rect for the life (`Map.bridge_pits`).

### Fire, water and charge on the ground (`data/world/ground.json`, `scripts/world/cells.gd`)

*N-4.2, spec §5. Not built: water flowing by height, smoke that blocks sight or drifts, cold and
ice on the cells, mud from water on earth.*

- **Every map is cut into 24 px cells**, each with a material: the map's `default` (camp earth,
  halls stone), then whole `places` (streets, market, square, lane, College stone; the hill grass;
  mill and road earth), then `paint` rects (the camp's grass patches). Water areas are water and
  solid ground is brick, whatever the paint. The grid is made the first time you step on a map
  in a life and **lasts the life**, so burnt ground stays ash until you wake again.
- **Fire** lights cells with fuel (grass, cloth, wood) at their Fire grade; earth, stone, brick
  and water never burn. A burning cell burns its material's `fuel_s` and then is **ash**, which
  can't burn again this life. Each second it lights each of its 8 neighbours with chance `base`
  0.3 (diagonals ×0.7, ×3 into cloth and oil), as a grade I fire. **Wind** (the day's weather) ×2
  downwind and ×0.5 upwind; a gale (wind 3) throws an ember 3 cells downwind every 2 s. A map has at
  most `max_burning` 96 burning cells; over that the oldest burn twice as fast.
- **What lights the ground:** Pillar's column and Kindle over their area; a fire shot where it
  ends (runs out, hits a foe or a wall); a burning prop under it. A burning cell sets the props
  on it alight (grade I).
- **Water** (Splash's cone, Douse, puddles and whirlpools, Undertow's wave) puts burning cells
  out in a puff of steam and wets cells for `wet_s` 20 s. A wet cell doesn't catch: fire on it
  only steams it dry. A doused cell keeps its unburnt fuel. The same water washes out a Saboteur's
  oil before it's lit (`wet_ground` tells the cult, [combat.md](combat.md)).
- **Lightning** strikes the cells along its line. A conducting cell (wet, water, iron) fills its
  connected network breadth-first as far as the Force grade reaches (`reach`: I 24 px, II 60,
  III 240, IV the whole network; at most 256 cells), charged for 4 s. Dry grass or cloth struck
  by lightning catches fire instead (`lightning_fire`).
- **Standing in it:** every 0.5 s a foe on a charged cell takes a 5 shock and on a burning cell
  `fire_dps` 8 a second; the wizard takes `self_k` ½ of either.
- **Weather** (`world.set_sky`, called at dawn and on arriving): `rain`/`storm` (weather `wet`)
  puts out every fire outdoors and nothing outdoors catches; `fire_spread` scales spread (heat
  ×1.5, snow ×0.5); wind and its direction drive it. The halls are `indoors`: no weather.
- **Shown:** burning cells are flames (arena `ember` zones with `cell`, not counted as your
  Embers). The view draws them all as one batch (`spells3d.gd` `_ground_fires`); only the 40
  nearest glow and the 2 nearest ask for a light. The ground decal has dark ash blots, blue wet
  blots and a crackle on charged cells, drawn as one batch of triangles, the ash and rubble from a
  cache rebuilt when they change (`world.gd` `draw_ground`).

### Owners and witnesses (`data/world/owners.json`, `scripts/world/deeds.gd`)

*N-4.4, environment spec §7.3, §9. Not built: faction temperaments, the guards coming (a toast for
now), fines, paying or fixing what you owe, nature regrowing, amends within 3 days, scar shapes as
evidence.*

- **Every prop has an owner** by map and place: in the camp the market's things are the traders',
  the great lamp's and the Guild workshop's the Guild's, the Mill's and its lane's the Mill's, the
  yard's, the College tents' and the duel ring's the College's, the rest the Watch's (public); the
  rest of the College ruins, the broken wall, the hill, the road and the whole halls are nobody's (nothing is owed there and nothing repairs, so a ruin remembers you for the
  life). Each kind has a **value** in crowns: hay 2, crate 4, barrel 6, post 20, cart 40.
- **Breaking or setting alight** an owned prop counts once until it's put back. If someone can see
  it (in town, 110 px by day, 55 at dusk and night, nothing solid between) the nearest one
  reacts by its value: under 10 crowns a grumble (−1 standing with the owner), up to 100 a demand
  ("That's 40 crowns you owe the Watch", −3, counted in `owed`), over that the watch is called (−10,
  +1 infamy, a toast). Setting a thing alight costs at least −3.
- **Nobody saw?** It goes on the life's `unseen` list; the next person to see where it was says so
  (−1 standing, +1 suspicion with the owner).
- **Good deeds:** putting out an owned prop's fire, or mending a damaged one with Rewind, is +1
  standing and +1 fame (someone near says thanks).
- **Owners mend** at dawn what was broken or burned `repair_days` ago (hay and crates 1, barrels
  and posts 2, the cart 3), on every map this life (`world.restore`).
- It all lives in `Run.life` (`standing`, `owed`, `fame`, `infamy`, `suspicion`, `unseen`) for the
  reputation and the economy to read when they're built; a new life starts clean.

## Economy, gear and repair (not built)

*Target design: [economy, gear, crafting and repair](/mnt/project-files/design/economy/economy-and-repair-spec.md)
(2026-10-22, tracker M0-15; visual: [Crowns and Crews](https://claude.ai/artifact/NabgfdAiiuJw8ghJPuBkzL)):
one coin (crowns), shops with weekly stock and one price formula (ring, season, scarcity, standing,
infamy), gear slots with fixed tiers and traits, reagents, salvage and benches, Spark Artifice device
charges, commissions, homes and loans, and repair crews who rebuild owned props on the environment
spec's timers using each town's stock. Money, gear and the home reset each life. Built so far: the
Spark Artifice part (reagents, salvage, the Lamplighters' bench and device charges, N-5.2: see
[growth.md](growth.md) "Devices" and "Salvage" above); the rest is not, and the gaps are in
[drift.md](drift.md).*

## Tests

`tools/tests/world_magic.gd` (each reaction, with real casts, including a Pillar grass fire that
spreads, Splash on a ground fire, a Spark on wet ground, a strike along a lamp rail, and the city's
barricade, winch, mirrors, Old Watch bridge and plaque, the undercroft's sluice and counterweight),
`tools/tests/unit.gd` (maps load, exits lead somewhere real, pits, reachability, per-map lamps; the
ground grid: spread, stone and water stop fire, ash, wind, rain, the cap, lightning reach by grade;
the camp's places and buildings, 24 lamps on 4 separate rail networks; every city spot reachable
from the wall gap with its gates open, every undercroft spot from the drain stair), `tools/map_preview.gd`
(top-down PNG/SVG of every map with rails and circuit letters; CI artifact `map-preview`).
