# Design vs build: where they differ (2026-10-22)

*The first pass, written when these specs were added. The GDD (`/mnt/project-files/design/gdd/`)
says what was meant; these specs say what is built. Where they differ the spec is right about the
game, and the difference is either logged here as a known change or a question for Harold in the
tracker's `needs`.*

## The direction moved on; the build is the ruins first playable

- **What's built** is the ruins first playable (GDD v2, 2026-10-19; milestones R1 and R2, PRs
  #23–#26): the survivors' camp, the College halls, and since N-1 a year of 13 moons to the Eclipse.
- **What's meant now** is the long-loop open-world RPG (Harold, 2026-10-20 and 2026-10-22: a
  year-long loop of 13 moons, many factions and schools, magic taken seriously and touching the
  world, the same person every life taking a different road). GDD v3 and its roadmap are being
  written in the "Full game build plan" thread. Until code for it lands, the specs describe the
  ruins build, and the R rows on the tracker are parked.

## Combat: the target spec vs the build

The [spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md) (2026-10-22,
tracker M0-4) is the design for spells and fights in the long-loop direction. Its §15 is the full
table; the big gaps:

| Target spec says | As built | Where |
| --- | --- | --- |
| Wind-up speeds Swift 0.4–0.6 s, Weave 0.8–1.2 s, Incant 1.5–2.5 s, Grand 3–5 s channelled | Swift, Weave and Incant built (0.4–1.8 s); no Grand spells yet | [combat.md](combat.md) |
| Letting go early cancels a wind-up | Cancels, except a Swift spell (and any spell under smart cast), which a tap commits: a cancelled bolt on every tap felt broken | [combat.md](combat.md) |
| Focus 2 by default, and "a flinch-level hit won't break you, a stagger will" | Focus 1, so the stagger rule holds under "Impact above Focus" (enemy hits are Impact 1–2 today); tune with the enemy pass (N-6) | [combat.md](combat.md) |
| Ley points refill Aether at 10/s; rest at shrines, camp fires, home | No ley points yet (they come with Ring 1's regions, N-7.1); rest is waking at dawn and meditating | [combat.md](combat.md) |
| Cantrips from the pool (Kindle, Douse, Lamplight, Stone Stair…), 2 slotted | Kindle and Douse only, fixed (`start_cantrips`) | [combat.md](combat.md) |
| Rest points change the book | Your desk (the story's `book` effect) | [combat.md](combat.md) |
| Eight schools, each with its own casting act and rule | No schools; Spheres only | [combat.md](combat.md) |
| One force × material table for props, tiles and units | Per-spell lists in `props.json` for fire, water, force, lightning | [world.md](world.md) |
| Combined spells from two mastered schools | Magicks (old Mill fight only) | [combat.md](combat.md) |
| Spells grow on seven visible axes over 20 levels in four stages, with breakthrough trials, Force grades I–V and prerequisite spells | 15 levels, stat numbers, milestone picks at 5/10/15, no prerequisites | [growth.md](growth.md) |

## Spell look: the target vs the build

The [spell visuals and VFX](/mnt/project-files/design/vfx/spell-visuals-spec.md) design (2026-10-22,
tracker M0-5) is how spells should look under the combat spec. The big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Six beats: intent cue, a telegraph that fills during the wind-up, release flash, travel, impact, a scar that stays | Telegraph marks and spell shapes; no intent cue, no fill, no lasting scars | [art.md](art.md) |
| Sigil rings on the telegraph (one per stage), Force-grade notches, per-stage body, light and trail | One look per spell, whatever its level | [art.md](art.md) |
| One SDF telegraph shader; one MultiMesh per particle kind; a light manager giving 4 real lights to the strongest spells, pools for the rest | Marks drawn by the view; pooled shapes in `spells3d.gd`; spell lights capped at 4 | [art.md](art.md) |
| A look per Sphere (shape, motion, light) and per school's casting act; material state looks | Colours per Sphere; fire, water, lightning prop effects only | [art.md](art.md), [world.md](world.md) |

## Spells and the environment: the target vs the build

The [spells and environment](/mnt/project-files/design/world/spells-and-environment-spec.md) design
(2026-10-22, tracker M0-6) is how magic should change the world. Its §13 is the full table; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| 16 materials plus flesh, scale and shade, one table (`data/materials.json`) by Force grade, with a weak version below grade | Per-spell lists in `props.json` for fire, water, force, lightning | [world.md](world.md) |
| States in three lanes (moisture, heat, integrity) with timers | Burning, ash, shoved, charged puddle, flared lamp | [world.md](world.md) |
| Fire spreads on a 24 px cell grid with wind; water flows by height; charge fills a network by grade | Burning props catch props within `spread` px; puddles; one charged puddle | [world.md](world.md) |
| Break stages, supports and telegraphed collapse; warded things never break | Shove only | [world.md](world.md) |
| Changes last the life; people and nature repair over days; Time mends by grade | Every reaction resets when you wake; Rewind mends within 34 px | [world.md](world.md) |
| Owners, values, witnesses, a reaction ladder, faction temperaments | People flinch and complain; the captain scolds fire | [world.md](world.md) |

## Enemies: the target vs the build

The [enemy combat spec](/mnt/project-files/design/combat/enemy-combat-spec.md) (2026-10-22, tracker
M0-7) is how enemies should fight under the combat spec. Its §15 is the full table; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Tiers Minion to Boss; a Break meter and Guard arcs beside Poise; Focus on enemy casters, and enemies that interrupt you | Per-kind numbers; Impact vs Poise reactions only | [combat.md](combat.md) |
| Body and armour materials with grades; states on units last half as long as on props | Hollows light-shy; units have no material | [combat.md](combat.md), [world.md](world.md) |
| A fight director (attack tokens, telegraph and interrupt budgets) and four AI tiers that use and fear terrain | `ai.gd` minds per kind; waves | [combat.md](combat.md) |
| `data/enemies.json` with factions; encounters name 2–3 terrain hooks and a knowledge route | `spells.json` `enemies`; encounters are waves, timers, leash and cracks | [combat.md](combat.md) |
| Regions keep a fixed tier; Unmoored counter-pick your last life; a Field Guide that carries over | Fixed per encounter; no bestiary | [combat.md](combat.md), [loop.md](loop.md) |

## Lives, saves and HUD: the target vs the build

The [lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) (M0-10), [save system spec](/mnt/project-files/design/lives/save-spec.md) (M0-11) and [UI and HUD spec](/mnt/project-files/design/ui/ui-hud-spec.md) (M0-12), 2026-10-22, are the design for lives,
saving and the screen. Each has a "today vs target" section; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| A life is a year (13 × 28 days); it ends only in a calamity, at the Great Eclipse, or by turning back the Hours after a calamity; other losses wake you injured 2 days later | The year, waking injured and the Turning's rule are built (N-1.1–1.3). No calamity is built yet (N-7.5), so the shrine never turns the Hours back in play: a life ends at the Eclipse or a story ending | [loop.md](loop.md) |
| Wake injured at the nearest shrine or camp you rested at this life | Always on your cot in the camp (it's the only rest point built) | [loop.md](loop.md) |
| Fixed events per moon; missed ones run their default and become appointments | Only the four calamities are dated, and only the Eclipse is known from the start; days you rest or travel past skip the camp's day scenes (N-1.5) | [loop.md](loop.md) |
| Ring 1: camp, fallen city, Mill fields as regions with their own maps | The fallen city's one map is the College halls (also reached by the camp's north stair, free); the Mill fields and Ring 2 are cards | [world.md](world.md) |
| `soul` / `life`; carry table with insight, bonds, roads, shortcuts, caches; school rank and Comprehension relearn | `soul` / `life` with a pure `carry` and insight (N-1.2); no bonds, roads, shortcuts, caches, schools or Comprehension yet; the Echo on spells and wells, revisions, Fluency | [loop.md](loop.md), [growth.md](growth.md) |
| Achievements grant titles people react to, roads, remembered caches, knowledge, Codex pages and sigils; about 25 in Ring 1; titles worn at the shrine | The frame, the profile copy and four titles (N-1.2); titles are worn from the Deeds tab and nobody reacts yet; no caches, Codex or sigils; the list is N-7.7 | [loop.md](loop.md) |
| Omens at the camp shrine on the first morning, each adding an achievement chance | Read on waking (no camp shrine is built); three Omens; The Early Bell does nothing until calamities (N-7.5); one achievement for finishing under any Omen | [loop.md](loop.md) |
| End card, then the Ledger's life page on the first morning | Built (N-1.2); the end card has no ending image yet, and the life page shows words, not icons | [loop.md](loop.md), [frame.md](frame.md) |
| Three slots; soul, life, per-map damage files and meta; atomic writes, checksums, a crash-proof Turning, versions | One slot (`user://slot1/`): soul, life and meta files swapped in from `.tmp` copies, a crash-proof Turning, a `version` field; no map damage files (nothing in the world lasts the life yet), no checksums or migrations | [loop.md](loop.md) |
| Four-star bar with stage rings, Focus and Overdraw, a 13-moon calendar with pins, Codex, region map | Four-star stand-in bar, Cadence, the calendar row (moons, weekday dots, calamity discs, time dial; no gold or silver pins yet), Ledger, map with the Reach and calendar tabs | [frame.md](frame.md) |

## Seasons, weather and calamities: the target vs the build

The [seasons, weather and calamities spec](/mnt/project-files/design/seasons/seasons-and-calamities-spec.md) (M0-13, 2026-10-22) is the design for the
year's seasons, weather and the four calamities. Its §11 has the full list; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Weather per region per day, the same every life; Almanac and forecast; weather acts on matter | No weather | [world.md](world.md) |
| Seasons dress the world (fields, rivers, dark slots, regrowth, travel) | Moons carry a season name; nothing reads it | [loop.md](loop.md) |
| A calamity: Signs, Eve stop, lethal zone, three waves, stakes, Held/Scarred/Fallen, aftermath, absent default | The four calamities are dated and pinned once known; none plays | [loop.md](loop.md) |

## Economy and repair: the target vs the build

The [economy, gear, crafting and repair](/mnt/project-files/design/economy/economy-and-repair-spec.md)
design (2026-10-22, tracker M0-15) is how money, gear and repairs should work. Its §13 is the table:

| Target says | As built | Where |
| --- | --- | --- |
| Crowns, shops with weekly stock, one price formula, selling, loans and the Reckoning | No money or shops; the save spec reserves `gold` and `items` | [world.md](world.md) |
| Staff, robe, charms and a belt; fixed tiers and traits with caps | No gear | [growth.md](growth.md) |
| Reagents, salvage, benches; Spark Artifice devices on charges refilled at a bench | No crafting or devices (N-5.2) | [combat.md](combat.md) |
| Commissions board, homes, rent | None (N-7.6) | [world.md](world.md) |
| Repair crews rebuild owned props over days from town stock | Every reaction resets when you wake (N-4.4) | [world.md](world.md) |

## Ring 1 places and fights: the target vs the build

The [Ring 1 places and fights spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
(2026-10-22, tracker M0-16) lays out Ring 1's maps, gates, puzzles and fights. Its §17 is the table;
the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Three regions, six maps: camp, city + halls + undercroft, fields + east road | Two maps (camp, halls); the Mill fields region is a card | [world.md](world.md) |
| The drain from the undercroft to the market cellar, kept open in later lives | Only the camp's free north stair to the halls | [world.md](world.md) |
| 24 Market lamps on 4 iron rail circuits meeting at the great lamp | 28 lamps in `street`, `lane` and `broken` groups; no rails | [world.md](world.md) |
| Twelve gates up to grade II, each with a second route; three Ring 2 locks | Three built doors in the halls (rune, burnt, collapsed stair) | [world.md](world.md) |
| 16 placed fights over 16 enemy kinds and a rival, 2 bosses (Kiln Warden, Lightdrinker), each with 2–3 terrain hooks | The patrol, four halls fights and the Warden | [combat.md](combat.md) |

## Known differences inside the build

| Doc says | As built | Where |
| --- | --- | --- |
| Root README 'The design decisions, as built': spell levels carry over, the wizard level halves each loop | True only for the old Mill fight (`Progression`). The ruins game's loop resets Practice, wells and Ring, with the Echo making relearning faster (Harold 2026-10-15) | [growth.md](growth.md) |
| Root README 'Not in this prototype': days 8 to 28 | The year runs all 364 days; the content is in the camp and halls only | [loop.md](loop.md) |
| GDD 02: seven Spheres | Four Spheres plus the Hours (Rewind) | [combat.md](combat.md) |
| GDD 03: Magicks in the loadout | Retired with the combat weight pass (N-2): no key casts them; discovery and tomes run only in the old Mill fight | [combat.md](combat.md) |

## Questions for Harold

None open from this pass; the open question is the direction itself (tracker M0-3).

## Powers and reputation: the target spec vs the build

The [powers and reputation spec](/mnt/project-files/design/powers/powers-and-reputation-spec.md)
(2026-10-22, tracker M0-14) is the design for factions, ranks, fame and blame. Its §14 is the full
table; none of it is built:

| Target spec says | As built | Where |
| --- | --- | --- |
| Standing −100 to +100 per power in seven tiers, moved by one deed stream (temperaments, duties, damage), with ripples to allies and feuds | No powers or standing | [story.md](story.md), [world.md](world.md) |
| A road power with ranks Initiate to Grandmaster: merit, standing, Ring, school mastery and a dated exam; one Associate power | No ranks or exams | [story.md](story.md) |
| Fame and infamy from witnessed deeds only, news travelling by road days, nicknames | No fame | [world.md](world.md) |
| The reaction ladder with numbers, suspicion for unwitnessed damage, amends within 3 days, fines and bounties | People flinch and complain; the captain scolds fire | [world.md](world.md) |
| One named rival per road who duels you before each rank exam | No rivals | [story.md](story.md) |

## People and side activities: the target spec vs the build

The [people and side activities spec](/mnt/project-files/design/people/people-and-side-activities-spec.md)
(2026-10-22, tracker M0-17) is the design for people, friendship and the side systems. Its §17 is the
full table; the big gaps:

| Target spec says | As built | Where |
| --- | --- | --- |
| About 20 named people in Ring 1 with schedule rows by slot, weekday, season, weather and events; reactions to weather, calamities, standing and what you did to them | 6 camp people with a schedule per time of day, overrides, `seek` and barks | [world.md](world.md) |
| Six bond tiers with scene gates, gifts and tastes as knowledge, companions (Guard, Cutter, Mender, Guide), sworn friends, one romance | No friendship; the soul keeps only the lives spec's bond floors | [world.md](world.md), [loop.md](loop.md) |
| Eight commissions, a six-rung dueling ladder, Star-charts and Sparks minigames | None | [story.md](story.md) |
| Rumours (date, person, lead), overheard talk, every missable event with a rumour 7 days ahead | Ledger clues only | [story.md](story.md) |
| Confrontations with three lamps; one inheritance per region | None | [story.md](story.md) |

## Audio: the target spec vs the build

The [audio spec](/mnt/project-files/design/audio/audio-spec.md) (2026-10-22, tracker M0-18; playable
[Sound Atlas](https://claude.ai/artifact/EEGxEw6Mertv8gHG5kn2NY)) is the design for sound and music.
Its §12 is the full table; the big gaps:

| Target spec says | As built | Where |
| --- | --- | --- |
| Wind-up that rises with the telegraph and ends in a catch, release, travel, impact by Force grade, broken-cast sound, stage layers | One cast sound per Sphere, one hit, one hurt | [frame.md](frame.md) |
| Buses (Music, Ambience, SFX: Spells/World/Foley, UI), settings sliders, a 24-voice pool with priority, `data/audio.json`, 2D placement | Everything on Master, 8 voices, gap and dB tables in `sfx.gd`, no placement | [frame.md](frame.md) |
| One sound per material result, footsteps by surface | None (one stone step) | [frame.md](frame.md), [world.md](world.md) |
| Ambience beds per weather, season, time and room; spot sounds | The night wind loop | [frame.md](frame.md) |
| Music states and 3-stem tracks; themes per power, region and season; calamity cues | No music | [frame.md](frame.md) |
