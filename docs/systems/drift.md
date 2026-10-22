# Design vs build: where they differ (2026-10-22)

*The first pass, written when these specs were added. The GDD (`/mnt/project-files/design/gdd/`)
says what was meant; these specs say what is built. Where they differ the spec is right about the
game, and the difference is either logged here as a known change or a question for Harold in the
tracker's `needs`.*

## The direction moved on; the build is the ruins first playable

- **What's built** is the ruins first playable (GDD v2, 2026-10-19; milestones R1 and R2, PRs
  #23–#26): the survivors' camp, the College halls, a 28-day loop to the Eclipse.
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
| No free bolts: every spell has a wind-up, a cost and a cooldown; a weak staff strike is the only free attack | Bolts are free and fire while held | [combat.md](combat.md) |
| Aether regen 3/s in a fight, refills fully only at rest; Overdraw adds Strain | 100 Aether, regen 12/s anywhere | [combat.md](combat.md) |
| A 4-spell book plus 2 cantrips; Ward held on RMB | 6 slots; Ward on C with 2 charges | [combat.md](combat.md), [growth.md](growth.md) |
| Focus: impact above it breaks a wind-up, for you and for enemies | No player interrupts | [combat.md](combat.md) |
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
| A life is a year (13 × 28 days); it ends only in a calamity, at the Great Eclipse, or by turning back the Hours after a calamity; other losses wake you injured 2 days later | A 28-day loop; any lethal fight, the shrine, the Eclipse or a story effect ends it | [loop.md](loop.md) |
| `soul` / `life`; carry table with insight, bonds, roads, shortcuts, caches; school rank and Comprehension relearn | `mem` / `lp`; the Echo on spells and wells, revisions, Fluency | [loop.md](loop.md), [growth.md](growth.md) |
| End card, then the Ledger's life page on the first morning | Death screen listing what you learnt | [loop.md](loop.md), [frame.md](frame.md) |
| Three slots; soul, life, per-map damage files and meta; atomic writes, checksums, a crash-proof Turning, versions | One `user://ruins.json`, plain overwrite, no versions | [loop.md](loop.md) |
| Four-star bar with stage rings, Focus and Overdraw, a 13-moon calendar, Codex, region map | Six-star bar, Cadence, 28-moon row, Ledger, map | [frame.md](frame.md) |

## Known differences inside the build

| Doc says | As built | Where |
| --- | --- | --- |
| Root README 'The design decisions, as built': spell levels carry over, the wizard level halves each loop | True only for the old Mill fight (`Progression`). The ruins game's loop resets Practice, wells and Ring, with the Echo making relearning faster (Harold 2026-10-15) | [growth.md](growth.md) |
| Root README 'Not in this prototype': days 8 to 28 | The loop runs all 28 days; the content is in the camp and halls only | [loop.md](loop.md) |
| GDD 02: seven Spheres | Four Spheres plus the Hours (Rewind) | [combat.md](combat.md) |
| GDD 03: Magicks in the loadout | Turned off in the ruins game (C is the Ward); Meteor and Conductor only in the old Mill fight | [combat.md](combat.md) |

## Questions for Harold

None open from this pass; the open question is the direction itself (tracker M0-3).
