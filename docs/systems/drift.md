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
| Eight schools, each with its own casting act and rule | Two schools built (`data/schools.json`): the 13 sphere spells are Astral Rite (Alignment, N-5.1); four devices are Spark Artifice (charges and the bench, N-5.2). Devices' Smoke Jar is Luna/water and the Tar Pot Mars/fire in the build's element terms. No other school yet; rank comes from Practice alone, not the power's merit, standing and exam; no casting acts in the art | [growth.md](growth.md), [combat.md](combat.md) |
| One force × material table for props, tiles and units | One table (`data/materials.json`), on props only so far | [world.md](world.md) |
| Combined spells from two mastered schools, learned at either school's hall | One built (N-5.3): the Star Lantern (Astral Rite + Spark Artifice), learned at the Lamplighters' bench only (the College has no hall scene for it yet). Magicks remain in the old Mill fight | [growth.md](growth.md), [combat.md](combat.md) |
| Spells grow on seven visible axes over 20 levels in four stages, with breakthrough trials, Force grades I–V and prerequisite spells | 20 levels in four stages with walls and trials (feat, insight, meditation), grades I–IV by stage, one minor axis per spell, prerequisites for the four signatures (N-3). Not yet: Sphere Comprehension, insight entries in the Ledger, meditation only at Sympathy places, grade V, the 1st Ring is still the yard trial alone | [growth.md](growth.md) |

## Spell look: the target vs the build

The [spell visuals and VFX](/mnt/project-files/design/vfx/spell-visuals-spec.md) design (2026-10-22,
tracker M0-5) is how spells should look under the combat spec. The big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Six beats: intent cue, a telegraph that fills during the wind-up, release flash, travel, impact, a scar that stays | Telegraph marks and spell shapes; no intent cue, no fill, no lasting scars | [art.md](art.md) |
| Sigil rings on the telegraph (one per stage), Force-grade notches, per-stage body, light and trail | A ring of sigils per stage on Pillar's and the meteor's zones only; otherwise one look per spell | [art.md](art.md) |
| One SDF telegraph shader; one MultiMesh per particle kind; a light manager giving 4 real lights to the strongest spells, pools for the rest | Marks drawn by the view; pooled shapes in `spells3d.gd`; spell lights capped at 4 | [art.md](art.md) |
| A look per Sphere (shape, motion, light) and per school's casting act; material state looks | Colours per Sphere; fire, water, lightning prop effects only | [art.md](art.md), [world.md](world.md) |

## Spells and the environment: the target vs the build

The [spells and environment](/mnt/project-files/design/world/spells-and-environment-spec.md) design
(2026-10-22, tracker M0-6) is how magic should change the world. Its §13 is the full table; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| 16 materials plus flesh, scale and shade, one table (`data/materials.json`) by Force grade, with a weak version below grade | The table and grades are built (N-4.1) but act only on the four prop kinds; tiles, walls, lamps and units have no material yet; spells name their force in `materials.json` carriers, not in `spells.json` `forces`; most ops (reveal, steam clouds, freeze, explode...) have no thing to act on yet | [world.md](world.md) |
| States in three lanes (moisture, heat, integrity) with timers | On props: smoulder, burning, ash, chilled, brittle, wet, cracked, broken; plus charged puddle and flared lamp | [world.md](world.md) |
| Fire spreads on a 24 px cell grid with wind; water flows by height; charge fills a network by grade | Built (N-4.2): fire spreads on 24 px cells with wind, rain and a cap; water wets and puts out; lightning fills wet and metal networks by grade. Water doesn't flow; smoke doesn't block sight or drift; no cold or mud on cells; arena puddles are still their own zones beside the cells | [world.md](world.md) |
| Break stages, supports and telegraphed collapse; warded things never break | Props crack and break by Impact grade and hp (a flattened heap, no broken meshes). Supports and collapse built (N-4.3) for one structure, the camp's leaning gallery; rubble slows and Impact II clears it. No ceilings, bridges or towers yet, no grade gates in map data, rubble isn't cleared by people over days | [world.md](world.md) |
| Changes last the life; people and nature repair over days; Time mends by grade | Changes last the life and owners mend their props after 1–3 dawns (N-4.4); nature doesn't regrow burned ground yet; Rewind mends within 34 px, not by grade | [world.md](world.md) |
| Owners, values, witnesses, a reaction ladder, faction temperaments | Owners, values, witnesses and the ladder's three steps built (N-4.4); the guards are a toast and a standing cost; fires enemies start are blamed on you like your own; no faction temperaments yet | [world.md](world.md) |

## Enemies: the target vs the build

The [enemy combat spec](/mnt/project-files/design/combat/enemy-combat-spec.md) (2026-10-22, tracker
M0-7) is how enemies should fight under the combat spec. Its §15 is the full table; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Tiers Minion to Boss; a Break meter and Guard arcs beside Poise; Focus on enemy casters, and enemies that interrupt you | Tiers and the Break meter built (N-6.1); the built kinds keep their numbers (the Dust Hollow has 22 HP, a Minion's range is 10–16). A Guard arc on the Shieldman (N-6.3) and the Shieldknight (N-6.6; its iron shield turns 35°/s, a number the spec doesn't give). Armour takes double wear while Broken. Not yet: enemies that interrupt you | [combat.md](combat.md) |
| Body and armour materials with grades; states on units last half as long as on props | Bodies built with burning, oil, panic and spread (N-6.2). Leather, mail and plate layers with grades, sundering, lightning through metal and fire heating it built (N-6.6); the grade is checked against a hit's Impact (there is no separate force grade yet), and a light hit lets a fixed share through. Not yet: robe, rune-plate, bark, ice and scale layers, frost and freezing joints, plate rusting, a Soldier dropping prone to strip hot plate, a nameplate change on sundering, frost and lightning states on units, husks resisting lightning | [combat.md](combat.md), [world.md](world.md) |
| A fight director (attack tokens, telegraph and interrupt budgets) and four AI tiers that use and fear terrain | Attack tokens and the reach rule built (N-6.1; distance stands in for "off-screen"); no telegraph or interrupt budget yet, minds still per kind | [combat.md](combat.md) |
| `data/enemies.json` with factions; encounters name 2–3 terrain hooks and a knowledge route | `data/enemies.json` with faction, role, tier, body and lesson (N-6.1); brigands built (N-6.3), their fights placed (N-7.1.6); encounters are still waves, timers, leash and cracks. The Lantern-eater, Choir and Overdrawn Husk built too (placed in the city's depot, square and glassworks). The Knights' picket built (N-6.6: Squire, Shieldknight, Silencer; `picket`, on the east road; the Squire's Sunbrand mark not yet). The cult's first cell built (N-6.7: Acolyte, Saboteur; `watch_cell`, in the Old Watch); the Saboteur only splashes and lights oil (cutting ropes and dropping portcullises wait for props that have them), and Acolytes are flesh, not shade. Not yet: the Shade-binder, Chronomancer and Hierophant, the Lancer, Oathsworn Adept and Knight-Captain | [combat.md](combat.md) |
| Regions keep a fixed tier; Unmoored counter-pick your last life; a Field Guide that carries over | Fixed per encounter. The Field Guide built (N-6.5) with seen, beaten, weakness found and mastered; mastery is "beaten 10 times with the weakness found", not "beaten three different ways", and no portraits or nameplates yet (the lesson shows in the Guide and a toast) | [combat.md](combat.md), [loop.md](loop.md) |
| People yield or flee; sparing or finishing a yielded enemy moves fame and standing | Brigands, Knights and the cult yield and flee (N-6.4, N-6.6, N-6.7); everyone kneeling when you win is spared and counted (`Run.life` "spared"). Not yet: finishing a kneeling enemy, fame and standing (no reputation system yet), elves, dwarves and fae | [combat.md](combat.md) |

## Lives, saves and HUD: the target vs the build

The [lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) (M0-10), [save system spec](/mnt/project-files/design/lives/save-spec.md) (M0-11) and [UI and HUD spec](/mnt/project-files/design/ui/ui-hud-spec.md) (M0-12), 2026-10-22, are the design for lives,
saving and the screen. Each has a "today vs target" section; the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| A life is a year (13 × 28 days); it ends only in a calamity, at the Great Eclipse, or by turning back the Hours after a calamity; other losses wake you injured 2 days later | The year, waking injured and the Turning's rule are built (N-1.1–1.3). No calamity is built yet (N-7.5), so the shrine never turns the Hours back in play: a life ends at the Eclipse or a story ending | [loop.md](loop.md) |
| Wake injured at the nearest shrine or camp you rested at this life | Always on your cot in the camp (it's the only rest point built) | [loop.md](loop.md) |
| Fixed events per moon; missed ones run their default and become appointments | The frame is built (N-1.5) with two fixed events (the Knights reach the camp, the Iron Gate shuts); moons 1–3's full set comes with N-7.2. The camp's own day scenes are still skipped on days you rest or travel past. No white pins for your own plans yet | [loop.md](loop.md) |
| Ring 1: camp, fallen city, Mill fields as regions with their own maps | The fallen city has its streets (N-7.1.2) and the College halls (also reached by the camp's north stair, free); and the undercroft (N-7.1.3); the Mill fields have their map (N-7.1.4) and the east road beyond it (N-7.1.5); Ring 2 regions are cards | [world.md](world.md) |
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
| Weather per region per day, the same every life; Almanac and forecast; weather acts on matter | Weather per region per day, the same every life, pinned calamity days, the Almanac on the calendar, Aldous's forecast (N-4.5.1); rain, wind and fire spread act on the ground (N-4.2). Not yet: frost and snow on matter, sight, storm strikes, rain or snow on screen, a turn at a time slot, signs in the sky, a mark for days a spell changed | [world.md](world.md) |
| Seasons dress the world (fields, rivers, dark slots, regrowth, travel) | Moons carry a season name; nothing reads it | [loop.md](loop.md) |
| A calamity: Signs, Eve stop, lethal zone, three waves, stakes, Held/Scarred/Fallen, aftermath, absent default | The four calamities are dated and pinned once known; none plays | [loop.md](loop.md) |

## Economy and repair: the target vs the build

The [economy, gear, crafting and repair](/mnt/project-files/design/economy/economy-and-repair-spec.md)
design (2026-10-22, tracker M0-15) is how money, gear and repairs should work. Its §13 is the table:

| Target says | As built | Where |
| --- | --- | --- |
| Crowns, shops with weekly stock, one price formula, selling, loans and the Reckoning | No money or shops; the save spec reserves `gold` and `items` | [world.md](world.md) |
| Staff, robe, charms and a belt; fixed tiers and traits with caps | No gear | [growth.md](growth.md) |
| Reagents, salvage, benches; Spark Artifice devices on charges refilled at a bench | Built (N-5.2): four devices on charges, five reagents, salvage from crates, barrels and carts, the Lamplighters' bench in the camp. Not yet: crowns, ready-made charges at 2× (a never-trained wizard pays double reagents at the bench instead), the bench's 2 cr fee, Quicksilver at Adept, the Economy axis trimming glass, the Field kit charm, other benches, herb gathering | [growth.md](growth.md), [combat.md](combat.md) |
| Refilling takes one hour on the clock | It takes the time of day (the clock has no hours yet) | [growth.md](growth.md) |
| Taking salvage from owned debris is theft if witnessed | Salvage ignores ownership until owners and witnesses (N-4.4) | [world.md](world.md) |
| Commissions board, homes, rent | None (N-7.6) | [world.md](world.md) |
| Repair crews rebuild owned props over days from town stock | Owners put their props back after 1–3 dawns, with no crew walking out and no stock spent (N-4.4) | [world.md](world.md) |

## Ring 1 places and fights: the target vs the build

The [Ring 1 places and fights spec](/mnt/project-files/design/places/ring1-places-and-fights-spec.md)
(2026-10-22, tracker M0-16) lays out Ring 1's maps, gates, puzzles and fights. Its §17 is the table;
the big gaps:

| Target says | As built | Where |
| --- | --- | --- |
| Three regions, six maps: camp, city + halls + undercroft, fields + east road | Built: all six maps | [world.md](world.md) |
| The drain from the undercroft to the market cellar, kept open in later lives | Built (N-7.1.3): the counterweight or Lightning II on the chain opens the grate for good (a soul memory); camp and undercroft join by exits that wait for it. Not yet: shutting it again for Lantern Night, the flooded-channel crate route | [world.md](world.md) |
| The camp re-dressed: new places, enterable inn, smithy and Guild workshop, 24 Market lamps on 4 iron rail circuits meeting at the great lamp | Built (N-7.1.1): places, four buildings, the great lamp and its open coupling, the circuits as iron cells that carry lightning. Not yet: the cellar grate going anywhere, the broken wall's climb-down, the gate cart and the oil shed, the straw targets and workroom moved, a bridge to join two circuits, the cascade | [world.md](world.md) |
| The city (§4.1): places, landmarks, the Old Watch's rope lift, the drain stair, ley points at shrines, the house for sale | Built (N-7.1.2): every place, the Old Watch felled as a bridge (its rect moved to span the edge it falls across), the shrine (spellbook only), the house you can walk into. Not yet: the rope lift, the drain stair (N-7.1.3), ley points, buying the house |
| The Mill fields (§6): pond, sluice, islet ley stone, wheel as a motor, granary cellar, bramble commission, footbridge that breaks | Built (N-7.1.4): the map and its places, the deep pond that the sluice drains (the wheel stops while it's dry, for the life rather than a day), the islet stone (no ley point yet), the cold crack (sealed), webs and bramble that burn. Not yet: the granary cellar (D8), the wheel as a motor (P3), the footbridge breaking (P8), freezing or planking across the pond, the bramble commission, Aldous's reactions |
| The east road (§7): picket, toll bridge, waystation cellar, quarry scaffold, Holds road | Built (N-7.1.5): the map and its places, the cellar door as a gate (Impact II or Fire II on its bar, or fire on the vent smokes them out), the quarry scaffold that falls, the Holds gate open in Ashmoon only (the Holds a stand-in). Not yet: the toll's talk route, the toll bridge breaking for the life, the Knights arriving only from Ashmoon 2, smoking out with a Smoke Jar or flooding |
| Twelve gates up to grade II, each with a second route; three Ring 2 locks | Three built doors in the halls (rune, burnt, collapsed stair); the city's D3 barricade, D4 shutter (Impact II, or the winch at Lightning II), D5 Archive gate (sealed; its rubble and plaque), D11's bakery heap, and P5's lens door (mirrors by day, or the fuse once known). The lens only takes the sun; Lamplight and the furnace light don't turn it yet | [world.md](world.md) |
| 16 placed fights over 16 enemy kinds and a rival, 2 bosses (Kiln Warden, Lightdrinker), each with 2–3 terrain hooks | Built (N-7.1.6): F1, F3–F11, F13–F15, F17 placed (see combat.md), the four halls fights and the Warden. Not yet: the duel ring's ladder in place (F2), Lantern Night and the Lightdrinker (F16), the bounty hunters at the quarry when Wanted, the picket only on provocation, the fights' story slots, the refill tied to a dead Captain | [combat.md](combat.md) |

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
| The reaction ladder with numbers, suspicion for unwitnessed damage, amends within 3 days, fines and bounties | The ladder with numbers, suspicion, fame and infamy counted in `Run.life` (N-4.4); no amends, fines or bounties, and fame doesn't travel | [world.md](world.md) |
| One named rival per road who duels you before each rank exam | No rivals | [story.md](story.md) |

## People and side activities: the target spec vs the build

The [people and side activities spec](/mnt/project-files/design/people/people-and-side-activities-spec.md)
(2026-10-22, tracker M0-17) is the design for people, friendship and the side systems. Its §17 is the
full table; the big gaps:

| Target spec says | As built | Where |
| --- | --- | --- |
| About 20 named people in Ring 1 with schedule rows by slot, weekday, season, weather and events; reactions to weather, calamities, standing and what you did to them | Schedule rows built (N-7.2.1: weekdays, seasons, moons, slots, weather, `if`, map, away, doing, cover in rain, busy, one seeker a day, three memories; the 7-day away check). Still 6 camp people; Aldous's rows send him to his fields. Not yet: events placing people, calamity tiers, standing and fame reactions, the bucket line, the Ledger's people page | [world.md](world.md) |
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
