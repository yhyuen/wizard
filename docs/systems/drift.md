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

## Known differences inside the build

| Doc says | As built | Where |
| --- | --- | --- |
| Root README 'The design decisions, as built': spell levels carry over, the wizard level halves each loop | True only for the old Mill fight (`Progression`). The ruins game's loop resets Practice, wells and Ring, with the Echo making relearning faster (Harold 2026-10-15) | [growth.md](growth.md) |
| Root README 'Not in this prototype': days 8 to 28 | The loop runs all 28 days; the content is in the camp and halls only | [loop.md](loop.md) |
| GDD 02: seven Spheres | Four Spheres plus the Hours (Rewind) | [combat.md](combat.md) |
| GDD 03: Magicks in the loadout | Turned off in the ruins game (C is the Ward); Meteor and Conductor only in the old Mill fight | [combat.md](combat.md) |

## Questions for Harold

None open from this pass; the open question is the direction itself (tracker M0-3).
